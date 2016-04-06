SparkleFormation.dynamic(:jackal_image) do |name, opts={}|
  ec2_required_info = [:image_id, :key_name, :instance_type]

  dynamic!(:jackal_token_validator, name, opts)

  unless(opts[:image_instance_id])

    ec2_required_info.each do |req_value|
      unless(opts[req_value])
        parameters.set!("#{name}_#{req_value}".to_sym).type 'String'
      end
    end

    base_instance = dynamic!(:ec2_instance, "#{name}_jackal_image".to_sym) do
      properties do
        ec2_required_info.each do |req_value|
          set!(req_value, opts.fetch(req_value, ref!("#{name}_#{req_value}".to_sym)))
        end
        if(opts[:user_data])
          user_data opts[:user_data]
        else
          user_data base64!(
            join!(
              "#!/bin/bash\n",
              "apt-get update\n",
              "apt-get -y install python-setuptools\n",
              "easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz\n",
              '/usr/local/bin/cfn-init -v --region ',
              region!,
              ' -s ',
              stack_name!,
              " -r #{resource_name!}\n",
              "cfn-signal -e $? -r 'Provision complete' --resource #{resource_name!} --region ",
              region!,
              ' --stack ',
              stack_name!
            )
          )
        end
      end
      unless(opts[:user_data])
        creation_policy.resource_signal do
          count 1
          timeout 'PT30M'
        end
      end
    end
  end

  image_resource = resources.set!("#{name}_jackal_image".to_sym) do
    type 'Custom::AmiRegister'
    properties do
      service_token opts.fetch(:jackal_service_token, ref!(:jackal_service_token))
      parameters do
        name join!(
          "jackal-image-#{name}",
          opts.fetch(
            :image_instance_id,
            ref!("#{name}_jackal_image_ec2_instance".to_sym)
          ),
          :options => {
            :delimiter => '-'
          }
        )
        instance_id opts.fetch(
          :image_instance_id,
          ref!("#{name}_jackal_image_ec2_instance".to_sym)
        )
        region region!
        description opts.fetch(
          :image_description,
          "Jackal Generated Image (#{name})"
        )
        no_reboot opts.fetch(:no_reboot, true)
      end
    end
  end

  outputs.set!("#{name}_ami_id".to_sym).value attr!("#{name}_jackal_image", :ami_id)

  opts[:image_instance_id] ? image_resource : base_instance

end
