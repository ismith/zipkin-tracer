require 'hermann/producer'
require 'hermann/discovery/zookeeper'
require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  # This class sends information to Zipkin through Kafka.
  # Spans are encoded using Thrift
  class ZipkinKafkaTracer < ZipkinTracerBase
    DEFAULT_KAFKA_TOPIC = "zipkin_kafka".freeze

    def initialize(options = {})
      @topic  = options[:topic] || DEFAULT_KAFKA_TOPIC
      broker_ids = Hermann::Discovery::Zookeeper.new(options[:zookeepers]).get_brokers
      @producer  = Hermann::Producer.new(nil, broker_ids)
      super(options)
    end

    def flush!
      resolved_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans)
      resolved_spans.each do |span|
        buf = ''
        trans = Thrift::MemoryBufferTransport.new(buf)
        oprot = Thrift::BinaryProtocol.new(trans)
        span.to_thrift.write(oprot)
        @producer.push(buf, topic: @topic).value!
      end
    rescue Exception
      # Ignore socket errors, etc
    end
  end
end
