package io.bytebakehouse.train.company.orchestrator.config;

import org.hibernate.type.SqlTypes;
import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configures Hibernate to properly handle PostgreSQL enum types.
 */
@Configuration
public class HibernateConfig {

    @Bean
    public HibernatePropertiesCustomizer hibernatePropertiesCustomizer() {
        return hibernateProperties -> {
            // Register PostgreSQL enum type descriptor
            hibernateProperties.put("hibernate.type.jdbc_type_code", SqlTypes.NAMED_ENUM);
        };
    }
}
