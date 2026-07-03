package com.bhook.upload;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class UploadApplication {
    public static void main(String[] args) {
        SpringApplication.run(UploadApplication.class, args);
    }
}
