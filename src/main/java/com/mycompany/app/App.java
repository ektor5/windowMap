package com.mycompany.app;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.functions.MapFunction;

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

		System.out.println( "Hello World!" );

		String topic = "lala";
		String address = "localhost";

		/* Consumer */

		FlinkKafkaConsumer<String> myConsumer =
			createStringConsumerForTopic(topic, address, "123");

		myConsumer.setStartFromLatest();

		DataStream<String> stream = env.addSource(myConsumer);

		/* Producer */

		FlinkKafkaProducer<String> myProducer = createStringProducer(topic+"flinked",address+":9092");
		myProducer.setWriteTimestampToKafka(true);

		windowMap lala = new windowMap(WINDOWSIZE);
		stream.rebalance().map(lala).print();


		stream.addSink(myProducer);

		/* Exec */

		env.execute();
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
