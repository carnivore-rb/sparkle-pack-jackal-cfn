SparkleFormation.dynamic(:jackal_stack) do |name, args={}|
  resources.set!("#{name}_jackal_stack".to_sym) do
    type 'Custom::JackalStack'
    properties do
      service_token args.fetch(:service_token, ref!(:jackal_service_token))
    end
  end
end
