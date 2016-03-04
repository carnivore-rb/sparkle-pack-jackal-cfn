SparkleFormation.dynamic(:jackal_token_validator) do |name, args={}|
  unless(args[:jackal_service_token])
    root!.parameters.jackal_service_token.type 'String'
  end
end
