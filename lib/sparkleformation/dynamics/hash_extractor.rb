SparkleFormation.dynamic(:hash_extractor) do |name, args={}|
  resources.set!("#{name}_hash_extractor".to_sym) do
    type 'Custom::HashExtractor'
    properties do
      service_token args.fetch(:service_token, ref!(:jackal_service_token))
    end
  end
end
