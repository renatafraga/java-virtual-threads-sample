package edu.renata.fraga.java_virtual_threads_sample.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.lang.NonNull;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.web.servlet.config.annotation.AsyncSupportConfigurer;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Configuração para MVC com Threads Tradicionais
 */
@Configuration
@Profile("mvc-traditional")
public class MvcTraditionalThreadsConfig implements WebMvcConfigurer {

    @Bean("traditionalThreadTaskExecutor")
    public AsyncTaskExecutor applicationTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);
        executor.setMaxPoolSize(16);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("traditional-async-");
        executor.initialize();
        return executor;
    }

    @Override
    public void configureAsyncSupport(@NonNull AsyncSupportConfigurer configurer) {
        configurer.setTaskExecutor(applicationTaskExecutor());
        configurer.setDefaultTimeout(30_000);
    }
}
