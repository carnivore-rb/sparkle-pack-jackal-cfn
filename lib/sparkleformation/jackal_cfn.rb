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

  mappings do
    config do
      flavor do
        classic 'm1.small'
        vpc 't2.micro'
      end
      set!('ap-northeast-1'.disable_camel!) do
        classic_ami_id 'ami-d5665cbb'
        vpc_ami_id 'ami-41675d2f'
      end
      set!('ap-southeast-1'.disable_camel!) do
        classic_ami_id 'ami-5a6fa039'
        vpc_ami_id 'ami-5e6ea13d'
      end
      set!('ap-southeast-2'.disable_camel!) do
        classic_ami_id 'ami-d2d8fcb1'
        vpc_ami_id 'ami-8cdafeef'
      end
      set!('cn-north-1'.disable_camel!) do
        classic_ami_id 'ami-d97db4b4'
        vpc_ami_id 'ami-3378b15e'
      end
      set!('eu-central-1'.disable_camel!) do
        classic_ami_id 'ami-15f6ee79'
        vpc_ami_id 'ami-acf4ecc0'
      end
      set!('sa-east-1'.disable_camel!) do
        classic_ami_id 'ami-6219990e'
        vpc_ami_id 'ami-1c1b9b70'
      end
      set!('eu-west-1'.disable_camel!) do
        classic_ami_id 'ami-6d70c61e'
        vpc_ami_id 'ami-bf72c4cc'
      end
      set!('us-east-1'.disable_camel!) do
        classic_ami_id 'ami-59d6f933'
        vpc_ami_id 'ami-20d3fc4a'
      end
      set!('us-west-1'.disable_camel!) do
        classic_ami_id 'ami-cd2056ad'
        vpc_ami_id 'ami-842355e4'
      end
      set!('us-west-2'.disable_camel!) do
        classic_ami_id 'ami-a1c721c1'
        vpc_ami_id 'ami-25c52345'
      end
      set!('us-gov-west-1'.disable_camel!) do
        classic_ami_id 'ami-ecbbd9cf'
        vpc_ami_id 'ami-d6bbd9f5'
      end
    end
  end

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

  dynamic!(:iam_user, :jackal).properties do
    path '/'
    policies array!(
      ->{
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
            condition.string_equals.set!('ec2:ResourceTag/stack_id', stack_id!)
          },
          ->{
            effect 'Allow'
            action 'sqs:*'
            resource attr!(:jackal_sqs_queue, :arn)
          }
        )
      }
    )
  end

  dynamic!(:iam_policy, :stacks) do
    on_condition! :stacks_enabled
    properties do
      users [ref!(:jackal_iam_user)]
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

  dynamic!(:jackal_image, :jackal_cfn,
    :image_id => if!(:vpc_enabled, map!(:config, region!, :vpc_ami_id), map!(:config, region!, :classic_ami_id)),
    :instance_type => if!(:vpc_enabled, map!(:config, 'Flavor', :vpc), map!(:config, 'Flavor', :classic)),
    :service_token => ref!(:jackal_sns_topic)
  ) do
    properties do
      security_groups [ref!(:jackal_ec2_security_group)]
      network_interfaces if!(
        :vpc_enabled,
        array!(
          -> {
            device_index 0
            associate_public_ip_address 'true'
            subnet_id select!(0, ref!(:networking_subnet_ids))
          }
        ),
        []
      )
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
          ignoreErrors 'true'
        end
        commands('02_software_properties_old') do
          command 'apt-get install -yq python-software-properties'
          ignoreErrors 'true'
        end
        commands('02_software_properties_new') do
          command 'apt-get install -yq software-properties-common'
          ignoreErrors 'true'
        end
        commands('03_add_repository') do
          command 'apt-add-repository ppa:brightbox/ruby-ng -y'
        end
        commands('04_apt_reupdate') do
          command 'apt-get update'
        end
        commands('05_ruby_install') do
          command 'apt-get install -qy ruby2.2 ruby2.2-dev libyajl-dev build-essential libcurl3-dev libxslt1-dev libxml2 zlib1g-dev awscli'
        end
        commands('06_jackal_install') do
          command 'gem install --no-document jackal-cfn carnivore-sqs bundler'
        end
        commands('07_jackal_startup') do
          command '/etc/init.d/jackal start'
        end
        commands('08_pause_for_file_stabilization') do
          command 'sleep 180'
        end
        commands('09_notify_complete') do
          command join!(
            "cfn-signal -e 0 -r 'Provision complete' --resource #{resource_name!} --region ",
            region!,
            ' --stack ',
            stack_name!
          )
        end
        commands('10_pause_for_dramatic_effect') do
          command 'sleep 3500'
        end
        commands('11_kill_self') do
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
      image_id attr!(:jackal_cfn_jackal_image, :ami_id)
      key_name ref!(:jackal_cfn_key_name)
      instance_type if!(:vpc_enabled, map!(:config, 'Flavor', :vpc), map!(:config, 'Flavor', :classic))
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
            "#!/bin/bash\n",
            "while true\ndo\nsleep 3500\n",
            "tail -n 1 /opt/jackal/run.log | grep 'no message received'\n",
            "if [ $? -eq 0 ]\nthen\n",
            'AWS_ACCESS_KEY_ID="',
            ref!(:jackal_iam_access_key),
            '" AWS_SECRET_ACCESS_KEY="',
            attr!(:jackal_iam_access_key, :secret_access_key),
            '" aws autoscaling terminate-instance-in-autoscaling-group --should-decrement-desired-capacity --instance-id `curl -s http://169.254.169.254/latest/meta-data/instance-id` --region ',
            region!,
            "\nexit 0\nfi\ndone\n"
          )
          mode '000700'
        end
        commands('00_jackal_init') do
          command '/etc/init.d/jackal start'
        end
        commands('01_suicider') do
          command 'nohup bash -c /usr/local/bin/suicider &'
        end
      end
    end
  end

  dynamic!(:auto_scaling_group, :jackal) do
    properties do
      cooldown 500
      max_size ref!(:jackal_max_cluster_size)
      min_size 0
      availability_zones if!(:vpc_enabled, no_value!, azs!)
      VPCZoneIdentifier if!(:vpc_enabled, ref!(:networking_subnet_ids), no_value!)
      launch_configuration_name ref!(:jackal_auto_scaling_launch_configuration)
    end
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
      :jackal_sqs_queue_policy,
      :jackal_auto_scaling_scaling_policy,
      :jackal_auto_scaling_group
    )
    properties do
      service_token ref!(:jackal_sns_topic)
      parameters do
        ami_id attr!(:jackal_cfn_jackal_image, :ami_id)
        region region!
      end
    end
  end

end
