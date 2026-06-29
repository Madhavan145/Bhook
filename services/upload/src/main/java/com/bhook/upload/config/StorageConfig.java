package com.bhook.upload.config;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.SetBucketPolicyArgs;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Slf4j
@Configuration
public class StorageConfig {

    @Value("${bhook.storage.endpoint}") private String endpoint;
    @Value("${bhook.storage.access-key}") private String accessKey;
    @Value("${bhook.storage.secret-key}") private String secretKey;
    @Value("${bhook.storage.region}") private String region;
    @Value("${bhook.storage.bucket}") private String bucket;
    @Value("${bhook.storage.public-endpoint:${bhook.storage.endpoint}}") private String publicEndpoint;

    @Bean
    public MinioClient minioClient() {
        return MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .region(region)
                .build();
    }

    @Bean("presignMinioClient")
    public MinioClient presignMinioClient() {
        return MinioClient.builder()
                .endpoint(publicEndpoint)
                .credentials(accessKey, secretKey)
                .region(region)
                .build();
    }

    @Bean
    public CommandLineRunner ensureBucket(@Qualifier("minioClient") MinioClient client) {
        return args -> {
            try {
                boolean exists = client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
                if (!exists) {
                    client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                    log.info("Created object storage bucket '{}'", bucket);
                }
                client.setBucketPolicy(SetBucketPolicyArgs.builder()
                        .bucket(bucket)
                        .config(publicReadPolicy(bucket))
                        .build());
            } catch (Exception e) {
                log.warn("Bucket ensure failed for '{}': {}", bucket, e.toString());
            }
        };
    }

    /** Allow anonymous GET only on image prefixes that are safe to serve publicly. */
    private static String publicReadPolicy(String bucket) {
        return """
            {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},\
            "Action":["s3:GetObject"],"Resource":[\
            "arn:aws:s3:::%1$s/catalog_image/*",\
            "arn:aws:s3:::%1$s/vendor_logo/*",\
            "arn:aws:s3:::%1$s/vendor_cover/*",\
            "arn:aws:s3:::%1$s/profile_image/*"]}]}""".formatted(bucket);
    }
}
