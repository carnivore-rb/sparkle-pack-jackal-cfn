SparkleFormation.dynamic(:ami_manager) do |name, args={}|
  resources.set!("#{name}_ami_manager".to_sym) do
    type 'Custom::AmiManager'
    properties do
      service_token args.fetch(:service_token, ref!(:jackal_service_token))
    end
  end
end
