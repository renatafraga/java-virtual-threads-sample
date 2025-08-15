package edu.renata.fraga.java_virtual_threads_sample.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Configuração para WebFlux com Threads Tradicionais (padrão)
 */
@Configuration
@Profile("webflux-traditional")
public class WebFluxTraditionalConfig {

    @Bean
    public String configureReactorScheduler() {
        // Usa configuração padrão do Reactor (threads tradicionais)
        System.setProperty("reactor.schedulers.defaultBoundedElasticOnVirtualThreads", "false");
        return "webflux-traditional-configured";
    }
}
