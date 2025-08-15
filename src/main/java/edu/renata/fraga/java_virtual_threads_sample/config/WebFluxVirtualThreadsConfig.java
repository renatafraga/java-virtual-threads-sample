package edu.renata.fraga.java_virtual_threads_sample.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Configuração para WebFlux com Virtual Threads
 */
@Configuration
@Profile("webflux-virtual")
public class WebFluxVirtualThreadsConfig {

    @Bean
    public String configureReactorScheduler() {
        // Configura Reactor para usar Virtual Threads
        System.setProperty("reactor.schedulers.defaultBoundedElasticOnVirtualThreads", "true");
        return "webflux-virtual-configured";
    }
}
