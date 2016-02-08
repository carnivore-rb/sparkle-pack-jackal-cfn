SparkleFormation.new(:jackal_cfn_usage_example) do

  AWSTemplateFormatVersion '2010-09-09'
  description 'Jackal CFN Example Usage'

  parameters.jackal_service_token.type 'String'

  dynamic!(:orchestration_unit, :example).properties.parameters.exec 'cat /jackal-example.json'

  outputs do
    full_result.value attr!(:example_orchestration_unit, :orchestration_unit_result)
    key_result.value attr!(:example_orchestration_unit, :origin_stack)
  end

end
