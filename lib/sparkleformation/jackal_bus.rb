SparkleFormation.new(:jackal_bus).load(:jackal_base).overrides do

  description 'Jackal CFN Bus'

  dynamic!(:jackal_sqs, :jackal, :sns_enabled => true)

end
