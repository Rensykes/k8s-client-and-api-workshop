package io.bytebakehouse.train.company.orchestrator.config;

import org.flywaydb.core.Flyway;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;

import javax.sql.DataSource;

@Configuration
public class DatabaseConfig {

    @Bean
    @Order(1)
    public CommandLineRunner cleanDatabase(DataSource dataSource) {
        return args -> {
            Flyway flyway = Flyway.configure()
                    .dataSource(dataSource)
                    .cleanDisabled(false)
                    .load();
            flyway.clean();
            flyway.migrate();
        };
    }
}
