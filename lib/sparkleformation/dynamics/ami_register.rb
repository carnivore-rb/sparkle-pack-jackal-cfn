SparkleFormation.dynamic(:ami_register) do |name, args={}|
  resources.set!("#{name}_ami_register".to_sym) do
    type 'Custom::AmiRegister'
    properties do
      service_token args.fetch(:service_token, ref!(:jackal_service_token))
    end
  end
end
