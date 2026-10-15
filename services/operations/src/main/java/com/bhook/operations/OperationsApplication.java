package com.bhook.operations;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafka;

@SpringBootApplication
@EnableKafka
public class OperationsApplication {
    public static void main(String[] args) {
        SpringApplication.run(OperationsApplication.class, args);
    }
}
