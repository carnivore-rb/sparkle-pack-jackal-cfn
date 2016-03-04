SparkleFormation.new(:jackal_bus) do

  description 'Jackal CFN Bus'

  dynamic!(:jackal_sqs, :jackal, :sns_enabled => true)

end.load(:jackal_base)
