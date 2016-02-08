# SparklePack - Jackal CFN

This is a [SparkleFormation][1] [SparklePack][2] for [jackal-cfn][3]. It provides
integrations for the custom resources provided by the [jackal-cfn][3]
library as well as templates for worker setup and example usage.

## Integrations

### Dynamics

This [SparklePack][2] provides dynamics for custom resources provided
by [jackal-cfn][3]:

* `:ami_manager`
* `:ami_register`
* `:hash_extractor`
* `:jackal_stack`
* `:orchestration_unit`

It also provides a customized `:jackal_image` dynamic which will
create the resource as well as an output of the newly created
AMI ID.

### Templates

This [SparklePack][2] includes 3 templates:

1. `jackal_cfn` - Creates a working processor to handle requests
2. `jackal_bus` - Creates _only_ the required message bus resources
3. `jackal_usage_example` - Example template to display usage of the OrchestrationUnit resource

_NOTE: The `jackal_cfn` template only supports the follow regions:_

* ap-northeast-1
* ap-southeast-1
* ap-southeast-2
* cn-north-1
* eu-central-1
* eu-west-1
* sa-east-1
* us-east-1
* us-west-1
* us-west-2
* us-gov-west-1

## Usage

_NOTE: Assumes a working `sfn` setup. (see: [Getting started guide][4])_

### Setup

First, include the [SparklePack][2] into the bundle by adding this line to
the `./Gemfile`:

```ruby
gem 'sparkle-pack-jackal-cfn'
```

Next, update the local bundle:

```
$ bundle update
```

Now enable the [SparklePack][2] within the `.sfn` configuration file:

```ruby
Configuration.new do
  ...
  sparkle_pack 'sparkle-pack-jackal-cfn'
  ...
end
```

### Build a jackal-cfn processor

To use the [jackal-cfn][3] resources, a processor instance must be available. The
[SparklePack][2] provides a template to build a processor stack. This stack will
build a single EC2 instance which will be used as the base for an on demand
autoscaling group. To create the stack:

```
$ bundle exec sfn create STACK_NAME_PROCESSOR --file jackal_cfn
```

### Using the jackal-cfn processor

This [SparklePack][2] includes an example template that uses the `OrchestrationUnit`
resource to read the contents of a file on the running processor instance. The
contents of the file is a JSON serialized Hash that includes the ID of the
current stack. The example stack will return the full result as well as the
specific `"OriginStack"` value in the outputs:

```
$ bundle exec sfn create STACK_NAME_EXAMPLE --file jackal_usage_example --apply-stack STACK_NAME_PROCESSOR
```

### All in one

The templates in this [SparklePack][2] support nesting. To create a single stack
that includes the `jackal_cfn` template and the `jackal_usage_example` template,
create a new local template:

```ruby
# ./sparkleformation/full_jackal.rb

SparkleFormation.new(:full_jackal) do
  nest!(:jackal_cfn)
  nest!(:jackal_usage_example)
end
```

And create the nested stacks:

```
$ bundle exec sfn create STACK_NAME_ALL --file full_stack
```

## Info

* Repository: https://github.com/carnivore-rb/sparkle-pack-jackal-cfn
* Jackal CFN: https://github.com/carnivore-rb/jackal-cfn
* SparkleFormation: http://www.sparkleformation.io
* IRC: Freenode @ #carnivore

[1]: http://www.sparkleformation.io/
[2]: http://www.sparkleformation.io/docs/sparkle_formation/sparkle-packs.html
[3]: https://github.com/carnivore-rb/jackal-cfn
[4]: http://www.sparkleformation.io/docs/guides/getting-started.html