package com.mycompany.app;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Properties;
import java.util.regex.Pattern;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.serialization.SerializationSchema;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.typeutils.TypeExtractor;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.timestamps.AscendingTimestampExtractor;
import org.apache.flink.streaming.api.functions.windowing.AllWindowFunction;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.windowing.assigners.SlidingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.util.Collector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Hello world!
 */

public class App 
{
	final static Logger LOG = LoggerFactory.getLogger(App.class);
	public static void main( String[] args ) throws Exception
	{

		LOG.info("Starting Streaming Job");
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
		final Integer WINDOWSIZE = 10;

		env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

		Integer ntopics = Integer.parseInt(args[0]);
		System.out.println( "Hello World! " +  Integer.toString(ntopics));

		String element = "MyVariable";
		String address = "kafka";

		/* Consumer */
		ArrayList<FlinkKafkaConsumer<Float>> myConsumerArray = new ArrayList<FlinkKafkaConsumer<Float>>();
		ArrayList<DataStream<Float>> streamArray = new ArrayList<DataStream<Float>>();
		ArrayList<DataStream<String>> windowArray = new ArrayList<DataStream<String>>();
		ArrayList<FlinkKafkaProducer<String>> myProducerArray = new ArrayList<FlinkKafkaProducer<String>>();

		for (int i=0; i<ntopics; i++){
			myConsumerArray.add( createFloatConsumerForTopic(element+Integer.toString(i), address, "123"));
			myConsumerArray.get(i).setStartFromLatest();
			streamArray.add( env
				.addSource(myConsumerArray.get(i)));

			windowArray.add( streamArray.get(i)
				// tumbling count window of 100 elements size
				.windowAll(SlidingProcessingTimeWindows.of(Time.seconds(10),Time.seconds(1)))
				// compute the sum 
				.apply (new MeanAllWindow())
				.map(new MapFunction<Float,String>(){
					@Override
					public String map(Float f) throws Exception {
						return Float.toString(f);
					}
				} ));


			/* Producer */

			myProducerArray.add( createStringProducer(element+Integer.toString(i)+"flinked",address+":9092"));
			myProducerArray.get(i).setWriteTimestampToKafka(true);

			//windowMap lala = new windowMap(WINDOWSIZE);
			//stream.rebalance().map(lala).print();


			windowArray.get(i).addSink(myProducerArray.get(i));
		}

		/* Exec */

		env.execute();
	}
	public long extractTimestamp(Long element, long previousElementTimestamp) {
		return previousElementTimestamp;
	}
	
	public static class MeanAllWindow
			implements AllWindowFunction<Float, Float, TimeWindow>  {
		public void apply ( TimeWindow window,
				Iterable<Float> values,
				Collector<Float> out) throws Exception {
			float sum = 0;
			int n = 0;
			for (Float t: values) {
				sum += t;
				n++;
			}
			out.collect (new Float(sum/n));
		}
	}

	public static FlinkKafkaConsumer<String> createStringConsumerForTopic(
			String topic, String kafkaAddress, String kafkaGroup ) {

		Properties properties = new Properties();
		properties.setProperty("bootstrap.servers", kafkaAddress+":9092");
		// only required for Kafka 0.8
		properties.setProperty("zookeeper.connect", kafkaAddress+":2181");
		properties.setProperty("group.id", "test");

		FlinkKafkaConsumer<String> consumer = new FlinkKafkaConsumer<>(
				topic, new SimpleStringSchema(), properties);

		System.out.println( "Set consumer for " + topic );
		return consumer;
			}
	public static FlinkKafkaProducer<String> createStringProducer(
			String topic, String kafkaAddress){

		System.out.println( "Set producer for " + topic );
		return new FlinkKafkaProducer<>(kafkaAddress,
				topic, new SimpleStringSchema());
			}
	public static FlinkKafkaConsumer<Float> createFloatConsumerForTopic(
			String topic, String kafkaAddress, String kafkaGroup ) {

		Properties properties = new Properties();
		properties.setProperty("bootstrap.servers", "kafka:9092");
		// only required for Kafka 0.8
		properties.setProperty("zookeeper.connect", "zookeeper:2181");
		properties.setProperty("group.id", "test");

		FlinkKafkaConsumer<Float> consumer = new FlinkKafkaConsumer<>(
				topic, new SimpleFloatSchema(), properties);

		System.out.println( "Set consumer for " + topic );
		return consumer;
			}
	public static FlinkKafkaProducer<Float> createFloatProducer(
			String topic, String kafkaAddress){

		System.out.println( "Set producer for " + topic );
		return new FlinkKafkaProducer<>(kafkaAddress,
				topic, new SimpleFloatSchema());
			}
	public static class SimpleFloatSchema implements
		DeserializationSchema<Float>, SerializationSchema<Float>{

		public static byte[] toByteArray(float value) {
			byte[] bytes = new byte[4];
			ByteBuffer.wrap(bytes).putFloat(value);
			return bytes;
		}

		public static float toFloat(byte[] bytes) {
			return ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).getFloat();
		}

		@Override
		public byte[] serialize(Float element) {
			return toByteArray(element);
		}

		@Override
		public Float deserialize(byte[] message) {
			return toFloat(message);
		}

		@Override
		public boolean isEndOfStream(Float nextElement) {
			return false;
		}

		@Override
		public TypeInformation<Float> getProducedType() {
			return TypeExtractor.getForClass(Float.class);
		}
	}
		
	public static class windowMap implements MapFunction<String, String>{

		static private Integer i = 0;
		static private Float buf = 0.0f; 
		static private Integer window;

		public windowMap (Integer window){
			this.window = window;
		}

		@Override
		public String map(String value) throws Exception {
			if (i==0){
				buf = 0.0f;
			}

			i = (i+1) % window;
			buf += Float.parseFloat(value);

			System.out.println( "i " + i );
			System.out.println( "buf " + buf );

			if (i == 0){
				return "Kafka and Flink says: " + Float.toString(buf);
			}else{
				return "gne";
			}
		}
	}
}
