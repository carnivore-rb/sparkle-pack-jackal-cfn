SparkleFormation.dynamic(:orchestration_unit) do |name, args={}|
  dynamic!(:jackal_token_validator, name, args)
  resources.set!("#{name}_orchestration_unit".to_sym) do
    type 'Custom::OrchestrationUnit'
    properties do
      service_token args.fetch(:service_token, ref!(:jackal_service_token))
    end
  end
end
