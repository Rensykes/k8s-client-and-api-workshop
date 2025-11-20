package io.bytebakehouse.train.company.orchestrator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class TrainCompanyOrchestratorApplication {

	public static void main(String[] args) {
		SpringApplication.run(TrainCompanyOrchestratorApplication.class, args);
	}

}
