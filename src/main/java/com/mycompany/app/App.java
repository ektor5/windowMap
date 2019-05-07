package com.mycompany.app;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.functions.timestamps.AscendingTimestampExtractor;
import java.util.regex.Pattern;
import java.util.ArrayList;

import java.util.Properties;

/**
 * Hello world!
 *
 */
public class App 
{
	public static void main( String[] args ) throws Exception
	{

		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
		final Integer WINDOWSIZE = 10;

		env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

		Integer ntopics = Integer.parseInt(args[0]);
		System.out.println( "Hello World! " +  Integer.toString(ntopics));

		String element = "MyVariable";
		String address = "localhost";

		/* Consumer */

		ArrayList<FlinkKafkaConsumer<String>> myConsumerArray = new ArrayList<FlinkKafkaConsumer<String>>();
		ArrayList<DataStream<String>> streamArray = new ArrayList<DataStream<String>>();
		ArrayList<DataStream<String>> windowArray = new ArrayList<DataStream<String>>();
		ArrayList<FlinkKafkaProducer<String>> myProducerArray = new ArrayList<FlinkKafkaProducer<String>>();

		for (int i=0; i<ntopics; i++){
			myConsumerArray.add( createStringConsumerForTopic(element+Integer.toString(i), address, "123"));
			myConsumerArray.get(i).setStartFromLatest();
			streamArray.add( env
				.addSource(myConsumerArray.get(i)));

			windowArray.add( streamArray.get(i)
				.map(new MapFunction<String,Float>(){
					@Override
					public Float map(String s) throws Exception {
						return Float.parseFloat(s);
					}
				} )
				// tumbling count window of 100 elements size
				.windowAll(TumblingProcessingTimeWindows.of(Time.seconds(5)))
				// compute the sum 
				.sum(0)
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
