SparkleFormation.new(:jackal_cfn, :inherit => :jackal_bus) do

  description 'Jackal CFN'

  parameters do
    jackal_max_cluster_size do
      type 'Number'
      value 2
    end
    jackal_custom_packages do
      type 'CommaDelimitedList'
      default 'bash,jq'
    end
    networking_vpc_id do
      type 'String'
      default 'none'
    end
    networking_subnet_ids do
      type 'CommaDelimitedList'
      default 'none'
    end
    stacks_enabled do
      type 'String'
      default 'false'
    end
  end

  conditions do
    stacks_enabled equals!(
      ref!(:stacks_enabled),
      'true'
    )
  end

  registry!(:image_ids)

  conditions.vpc_enabled not!(equals!(ref!(:networking_vpc_id), 'none'))

  dynamic!(:ec2_security_group, :jackal) do
    properties do
      group_description join!(stack_name!, ' - Jackal compute security group')
      vpc_id if!(:vpc_enabled, ref!(:networking_vpc_id), no_value!)
      security_group_ingress array!(
        ->{
          ip_protocol 'tcp'
          from_port 22
          to_port 22
          cidr_ip '0.0.0.0/0'
        }
      )
    end
  end

  dynamic!(:iam_user, :jackal)

  dynamic!(:iam_role, :jackal) do
    properties do
      assume_role_policy_document do
        version '2012-10-17'
        statement array!(
          ->{
            effect 'Allow'
            principal.service ['ec2.amazonaws.com']
            action ['sts:AssumeRole']
          }
        )
      end
      path '/'
    end
  end

  dynamic!(:iam_policy, :jackal) do
    properties do
      policy_name 'service-access'
      policy_document.statement array!(
        ->{
          effect 'Allow'
          action [
            'ec2:RegisterImage',
            'ec2:DeregisterImage',
            'ec2:DescribeImages',
            'ec2:StopInstances',
            'ec2:CreateImage'
          ]
          resource '*'
        },
        ->{
          effect 'Allow'
          action 'ec2:TerminateInstances'
          resource join!('arn:aws:ec2:', region!, ':', account_id!, ':instance/*')
          condition.string_equals.set!('ec2:ResourceTag/StackId', stack_id!)
        },
        ->{
          effect 'Allow'
          action 'autoscaling:TerminateInstanceInAutoScalingGroup'
          resource '*'
        },
        ->{
          effect 'Allow'
          action 'sqs:*'
          resource attr!(:jackal_sqs_queue, :arn)
        }
      )
      users [ref!(:jackal_iam_user)]
      roles [ref!(:jackal_iam_role)]
    end
  end

  dynamic!(:iam_policy, :stacks) do
    on_condition! :stacks_enabled
    properties do
      users [ref!(:jackal_iam_user)]
      roles [ref!(:jackal_iam_role)]
      policy_name 'stacks-access'
      policy_document.statement array!(
        ->{
          effect 'Allow'
          action 'cloudformation:*'
        },
        ->{
          effect 'Allow'
          action 'iam:*'
        }
      )
    end
  end

  dynamic!(:iam_access_key, :jackal).properties.user_name ref!(:jackal_iam_user)

  dynamic!(:iam_instance_profile, :jackal).properties do
    path '/'
    roles [ref!(:jackal_iam_role)]
  end

  dynamic!(:jackal_image, :jackal_cfn,
    :image_id => if!(:vpc_enabled, map!(:config, region!, :vpc_ami_id), map!(:config, region!, :classic_ami_id)),
    :instance_type => if!(:vpc_enabled, map!(:config, 'Flavor', :vpc), map!(:config, 'Flavor', :classic)),
    :jackal_service_token => ref!(:jackal_sns_topic)
  ) do
    properties do
      security_groups if!(:vpc_enabled, no_value!, [ref!(:jackal_ec2_security_group)])
      iam_instance_profile ref!(:jackal_iam_instance_profile)
      network_interfaces if!(
        :vpc_enabled,
        array!(
          -> {
            device_index 0
            associate_public_ip_address 'true'
            subnet_id select!(0, ref!(:networking_subnet_ids))
            group_set [ref!(:jackal_ec2_security_group)]
          }
        ),
        []
      )
      tags!('StackId' => stack_id!)
    end
    metadata('AWS::CloudFormation::Init') do
      camel_keys_set!(:auto_disable)
      config do
        files('/etc/jackal/configuration.json') do
          content do
            jackal do
              require [
                'carnivore-sqs',
                'jackal-cfn'
              ]
              cfn do
                sources do
                  input do
                    type :sqs
                    args do
                      fog do
                        aws_access_key_id ref!(:jackal_iam_access_key)
                        aws_secret_access_key attr!(:jackal_iam_access_key, :secret_access_key)
                        region region!
                      end
                      queues [
                        ref!(:jackal_sqs_queue)
                      ]
                    end
                  end
                end
                config do
                  reprocess true
                  ami.credentials.compute do
                    aws_access_key_id ref!(:jackal_iam_access_key)
                    aws_secret_access_key attr!(:jackal_iam_access_key, :secret_access_key)
                    region region!
                  end
                  jackal_stack do
                    credentials do
                      storage do
                        aws_access_key_id ref!(:jackal_iam_access_key)
                        aws_secret_access_key attr!(:jackal_iam_access_key, :secret_access_key)
                      end
                      us_west_1 do
                        provider "aws"
                        aws_access_key_id ref!(:jackal_iam_access_key)
                        aws_secret_access_key attr!(:jackal_iam_access_key, :secret_access_key)
                        aws_region 'us-west-1'
                      end
                    end
                  end
                end
                callbacks [
                  'Jackal::Cfn::Resource',
                  'Jackal::Cfn::AmiRegister',
                  'Jackal::Cfn::AmiManager',
                  'Jackal::Cfn::JackalStack',
                  'Jackal::Cfn::OrchestrationUnit'
                ]
              end
            end
          end
        end
        files('/etc/init.d/jackal') do
          content "#!/bin/sh\nstart-stop-daemon --start --oknodo --user jackal --pidfile /var/run/jackal.pid --make-pidfile --chuid jackal --background --exec /bin/bash -- -c 'jackal -c /etc/jackal > /opt/jackal/run.log 2>&1'\n"
          mode '000755'
        end
        files('/jackal-example.json') do
          content.set!('OriginStack', stack_id!)
        end
        users.jackal.homeDir '/opt/jackal'
        commands('00_apt_update') do
          command 'apt-get update -q'
        end
        commands('00_ntp_sync') do
          command 'apt-get install ntpdate -qy && ntpdate -b -s pool.ntp.org'
        end
        commands('01_jackal_directory') do
          command 'mkdir /opt/jackal && chown jackal /opt/jackal'
        end
        commands('02_custom_packages') do
          command join!(
            'apt-get install -yq ',
            join!(
              ref!(:jackal_custom_packages),
              :options => {
                :delimiter => ' '
              }
            )
          )
        end
        commands('03_required_packages_install') do
          command 'apt-get install -qy ruby ruby-dev libssl-dev libyajl-dev build-essential libcurl3-dev libxslt1-dev libxml2 zlib1g-dev awscli jq'
        end
        commands('04_jackal_install') do
          command 'gem install --no-document jackal-cfn carnivore-sqs bundler'
        end
        commands('05_jackal_startup') do
          command '/etc/init.d/jackal start'
        end
        commands('06_pause_for_file_stabilization') do
          command 'sleep 180'
        end
        commands('07_notify_complete') do
          command join!(
            "cfn-signal -e 0 -r 'Provision complete' --resource #{resource_name!} --region ",
            region!,
            ' --stack ',
            stack_name!
          )
        end
        commands('08_pause_for_dramatic_effect') do
          command 'sleep 3500'
        end
        commands('09_kill_self') do
          command join!(
            'aws ec2 terminate-instances --instance-ids `curl -s http://169.254.169.254/latest/meta-data/instance-id` --region ',
            region!
          )
          env do
            set!('AWS_ACCESS_KEY_ID', ref!(:jackal_iam_access_key))
            set!('AWS_SECRET_ACCESS_KEY', attr!(:jackal_iam_access_key, :secret_access_key))
          end
        end
      end
    end
  end

  dynamic!(:auto_scaling_launch_configuration, :jackal) do
    properties do
      associate_public_ip_address if!(:vpc_enabled, true, false)
      image_id attr!(:jackal_cfn_jackal_image, :ami_id)
      key_name ref!(:jackal_cfn_key_name)
      instance_monitoring false
      instance_type if!(:vpc_enabled, map!(:config, 'Flavor', :vpc), map!(:config, 'Flavor', :classic))
      iam_instance_profile ref!(:jackal_iam_instance_profile)
      security_groups [ref!(:jackal_ec2_security_group)]
      user_data base64!(
        join!(
          "#!/bin/bash\n",
          '/usr/local/bin/cfn-init -v --region ',
          region!,
          ' -s ',
          stack_name!,
          " -r #{resource_name!}"
        )
      )
    end
    metadata('AWS::CloudFormation::Init') do
      camel_keys_set!(:auto_disable)
      config do
        files('/usr/local/bin/suicider') do
          content join!(
            "#!/bin/bash\nsleep 3550\n",
            'until [ "$(expr $(date +%s) - 300)" -gt "$(date +%s -r /opt/jackal/run.log)" ]; do sleep 3550; done',
            "\n",
            'aws autoscaling terminate-instance-in-auto-scaling-group --should-decrement-desired-capacity --instance-id `curl -s http://169.254.169.254/latest/meta-data/instance-id` --region ',
            region!,
            "\nexit 0\n"
          )
          mode '000700'
        end
        commands('00_jackal_init') do
          command '/etc/init.d/jackal start'
        end
        commands('01_suicider') do
          command 'at -f /usr/local/bin/suicider now'
        end
      end
    end
  end

  asg_resource = dynamic!(:auto_scaling_auto_scaling_group, :jackal, :resource_name_suffix => :auto_scaling_group) do
    properties do
      cooldown 500
      max_size ref!(:jackal_max_cluster_size)
      min_size 0
      availability_zones if!(:vpc_enabled, no_value!, azs!)
      VPCZoneIdentifier if!(:vpc_enabled, ref!(:networking_subnet_ids), no_value!)
      launch_configuration_name ref!(:jackal_auto_scaling_launch_configuration)
      tags array!(
        ->{
          key 'StackId'
          value stack_id!
          propagate_at_launch true
        }
      )
    end
    update_policy.auto_scaling_rolling_update.max_batch_size 1
  end

  dynamic!(:auto_scaling_scaling_policy, :jackal) do
    properties do
      adjustment_type 'ChangeInCapacity'
      auto_scaling_group_name ref!(:jackal_auto_scaling_group)
      cooldown 600
      scaling_adjustment 1
    end
  end

  dynamic!(:cloud_watch_alarm, :jackal) do
    properties do
      actions_enabled true
      alarm_actions [ref!(:jackal_auto_scaling_scaling_policy)]
      alarm_description 'Jackal Kickstart'
      comparison_operator 'GreaterThanOrEqualToThreshold'
      evaluation_periods 2
      metric_name 'ApproximateNumberOfMessagesVisible'
      namespace 'AWS/SQS'
      dimensions array!(
        ->{
          name 'QueueName'
          value attr!(:jackal_sqs_queue, :queue_name)
        }
      )
      period 60
      statistic 'Average'
      threshold 1
    end
  end

  resources.jackal_image_cleanup do
    type 'Custom::AmiManager'
    depends_on!(
      :jackal_cloud_watch_alarm,
      :jackal_sqs_queue_policy
    )
    properties do
      service_token ref!(:jackal_sns_topic)
      parameters do
        ami_id attr!(:jackal_cfn_jackal_image, :ami_id)
        region region!
      end
    end
  end

  outputs do
    jackal_iam_user.value ref!(:jackal_iam_user)
    jackal_iam_role.value ref!(:jackal_iam_role)
  end

end
