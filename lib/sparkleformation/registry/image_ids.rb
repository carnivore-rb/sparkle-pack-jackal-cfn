SfnRegistry.register(:image_ids) do
  mappings do
    config do
      flavor do
        classic 'm1.small'
        vpc 't2.micro'
      end
      {"ap-southeast-2"=>
        {"classic_ami_id"=>"ami-4efcdf2d", "vpc_ami_id"=>"ami-dec3e0bd"},
      "ap-northeast-1"=>
        {"vpc_ami_id"=>"ami-ecb0a682", "classic_ami_id"=>"ami-30b5a35e"},
      "sa-east-1"=>{"classic_ami_id"=>"ami-08f57a64", "vpc_ami_id"=>"ami-efe36c83"},
      "eu-west-1"=>{"vpc_ami_id"=>"ami-848001f7", "classic_ami_id"=>"ami-23ff7e50"},
      "us-west-1"=>{"classic_ami_id"=>"ami-f0e19c90", "vpc_ami_id"=>"ami-a2e499c2"},
      "us-west-2"=>{"vpc_ami_id"=>"ami-f954be99", "classic_ami_id"=>"ami-9252b8f2"},
      "us-east-1"=>{"vpc_ami_id"=>"ami-82fcf6e8", "classic_ami_id"=>"ami-28f9f342"},
      "ap-southeast-1"=>
        {"classic_ami_id"=>"ami-58549e3b", "vpc_ami_id"=>"ami-0d569c6e"},
      "eu-central-1"=>
        {"classic_ami_id"=>"ami-869879e9", "vpc_ami_id"=>"ami-209b7a4f"}}.each do |region_key, ami_data|
        set!(region_key.dup.disable_camel!) do
          ami_data.each do |ami_key, ami_id|
            set!(ami_key.dup, ami_id.dup)
          end
        end
      end
    end
  end
end
