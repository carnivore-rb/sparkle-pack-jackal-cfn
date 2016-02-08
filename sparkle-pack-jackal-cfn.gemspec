Gem::Specification.new do |s|
  s.name = 'sparkle-pack-jackal-cfn'
  s.version = '0.1.1'
  s.summary = 'Jackal CFN compute stacker'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/carnivore-rb/sparkle-pack-jackal-cfn'
  s.description = 'SparkleFormation pack for generating Jackal CFN compute stack'
  s.license = 'Apache-2.0'
  s.require_path = 'lib'
  s.add_runtime_dependency 'sparkle_formation', '>= 2.1.0'
  s.files = Dir['{lib,docs}/**/*'] + %w(sparkle-pack-jackal-cfn.gemspec README.md CHANGELOG.md LICENSE)
end
