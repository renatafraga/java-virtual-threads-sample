package edu.renata.fraga.java_virtual_threads_sample.controller;

import edu.renata.fraga.java_virtual_threads_sample.model.Person;
import edu.renata.fraga.java_virtual_threads_sample.service.PersonService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api")
public class MainController {

        private final PersonService personService;

        public MainController(PersonService personService) {
                this.personService = personService;
        }

        /**
         * Endpoint de documentação principal
         */
        @GetMapping("/")
        public Map<String, Object> welcome() {
                return Map.of(
                                "message", "Virtual Threads vs WebFlux Comparison API",
                                "timestamp", LocalDateTime.now(),
                                "profiles", Map.of(
                                                "mvc-traditional", "Spring MVC with traditional thread pool",
                                                "mvc-virtual", "Spring MVC with Virtual Threads",
                                                "webflux-traditional", "Spring WebFlux with traditional thread pool",
                                                "webflux-virtual", "Spring WebFlux with Virtual Threads"),
                                "endpoints", Map.of(
                                                "Spring MVC", Map.of(
                                                                "blocking", "/api/mvc/persons/blocking",
                                                                "async", "/api/mvc/persons/async",
                                                                "concurrent", "/api/mvc/persons/concurrent",
                                                                "threadInfo", "/api/mvc/thread-info"),
                                                "Spring WebFlux", Map.of(
                                                                "stream", "/api/webflux/persons/stream",
                                                                "list", "/api/webflux/persons/list",
                                                                "parallel", "/api/webflux/persons/parallel",
                                                                "threadInfo", "/api/webflux/thread-info")));
        }

        // ============ SPRING MVC ENDPOINTS ============

        /**
         * Spring MVC - Abordagem blocking tradicional
         */
        @GetMapping("/mvc/persons/blocking")
        public ResponseEntity<Map<String, Object>> getMvcPersonsBlocking(
                        @RequestParam(defaultValue = "10") int count) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                List<Person> persons = personService.getPersonsBlocking(count);

                long endTime = System.currentTimeMillis();

                Map<String, Object> response = Map.of(
                                "approach", "mvc-blocking",
                                "persons", persons,
                                "count", persons.size(),
                                "executionTimeMs", endTime - startTime,
                                "threadInfo", threadInfo,
                                "timestamp", LocalDateTime.now());

                return ResponseEntity.ok(response);
        }

        /**
         * Spring MVC - Abordagem blocking com I/O intensivo (demonstra vantagens das
         * Virtual Threads)
         */
        @GetMapping("/mvc/persons/blocking-intensive")
        public ResponseEntity<Map<String, Object>> getMvcPersonsBlockingIntensive(
                        @RequestParam(defaultValue = "10") int count) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                List<Person> persons = personService.getPersonsBlockingIntensive(count);

                long endTime = System.currentTimeMillis();

                Map<String, Object> response = Map.of(
                                "approach", "mvc-blocking-intensive",
                                "persons", persons,
                                "count", persons.size(),
                                "executionTimeMs", endTime - startTime,
                                "threadInfo", threadInfo,
                                "timestamp", LocalDateTime.now());

                return ResponseEntity.ok(response);
        }

        /**
         * Spring MVC - Abordagem assíncrona (pode usar Virtual Threads dependendo do
         * profile)
         */
        @GetMapping("/mvc/persons/async")
        public CompletableFuture<ResponseEntity<Map<String, Object>>> getMvcPersonsAsync(
                        @RequestParam(defaultValue = "10") int count) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                return personService.getPersonsAsync(count)
                                .thenApply(persons -> {
                                        long endTime = System.currentTimeMillis();
                                        String finalThreadInfo = personService.getCurrentThreadInfo();

                                        Map<String, Object> response = Map.of(
                                                        "approach", "mvc-async",
                                                        "persons", persons,
                                                        "count", persons.size(),
                                                        "executionTimeMs", endTime - startTime,
                                                        "initialThreadInfo", threadInfo,
                                                        "finalThreadInfo", finalThreadInfo,
                                                        "timestamp", LocalDateTime.now());

                                        return ResponseEntity.ok(response);
                                });
        }

        /**
         * Spring MVC - Processamento concorrente
         */
        @GetMapping("/mvc/persons/concurrent")
        public CompletableFuture<ResponseEntity<Map<String, Object>>> getMvcPersonsConcurrent(
                        @RequestParam(defaultValue = "5") int batches,
                        @RequestParam(defaultValue = "10") int countPerBatch) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                return personService.getPersonsConcurrent(batches, countPerBatch)
                                .thenApply(persons -> {
                                        long endTime = System.currentTimeMillis();
                                        String finalThreadInfo = personService.getCurrentThreadInfo();

                                        Map<String, Object> response = Map.of(
                                                        "approach", "mvc-concurrent",
                                                        "persons", persons,
                                                        "totalCount", persons.size(),
                                                        "batches", batches,
                                                        "countPerBatch", countPerBatch,
                                                        "executionTimeMs", endTime - startTime,
                                                        "initialThreadInfo", threadInfo,
                                                        "finalThreadInfo", finalThreadInfo,
                                                        "timestamp", LocalDateTime.now());

                                        return ResponseEntity.ok(response);
                                });
        }

        /**
         * Spring MVC - Informações sobre threads
         */
        @GetMapping("/mvc/thread-info")
        public ResponseEntity<Map<String, Object>> getMvcThreadInfo() {
                String threadInfo = personService.getCurrentThreadInfo();

                Map<String, Object> response = Map.of(
                                "approach", "mvc",
                                "threadInfo", threadInfo,
                                "timestamp", LocalDateTime.now(),
                                "activeThreadCount", Thread.activeCount(),
                                "availableProcessors", Runtime.getRuntime().availableProcessors());

                return ResponseEntity.ok(response);
        }

        // ============ SPRING WEBFLUX ENDPOINTS ============

        /**
         * Spring WebFlux - Stream de pessoas
         */
        @GetMapping(value = "/webflux/persons/stream", produces = MediaType.APPLICATION_NDJSON_VALUE)
        public Flux<Person> getWebFluxPersonsStream(@RequestParam(defaultValue = "10") int count) {
                return personService.getPersonsReactive(count)
                                .doOnSubscribe(
                                                subscription -> System.out.println("WebFlux Stream - "
                                                                + personService.getCurrentThreadInfo()))
                                .doOnNext(person -> System.out.println("Emitting person: " + person.name() + " on " +
                                                personService.getCurrentThreadInfo()));
        }

        /**
         * Spring WebFlux - Lista completa
         */
        @GetMapping("/webflux/persons/list")
        public Mono<Map<String, Object>> getWebFluxPersonsList(@RequestParam(defaultValue = "10") int count) {
                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                return personService.getPersonsReactiveList(count)
                                .map(persons -> {
                                        long endTime = System.currentTimeMillis();
                                        String finalThreadInfo = personService.getCurrentThreadInfo();

                                        return Map.of(
                                                        "approach", "webflux-reactive",
                                                        "persons", persons,
                                                        "count", persons.size(),
                                                        "executionTimeMs", endTime - startTime,
                                                        "initialThreadInfo", threadInfo,
                                                        "finalThreadInfo", finalThreadInfo,
                                                        "timestamp", LocalDateTime.now());
                                });
        }

        /**
         * Spring WebFlux - Processamento paralelo
         */
        @GetMapping("/webflux/persons/parallel")
        public Mono<Map<String, Object>> getWebFluxPersonsParallel(
                        @RequestParam(defaultValue = "5") int batches,
                        @RequestParam(defaultValue = "10") int countPerBatch) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                return personService.getPersonsReactiveList(batches, countPerBatch)
                                .map(persons -> {
                                        long endTime = System.currentTimeMillis();
                                        String finalThreadInfo = personService.getCurrentThreadInfo();

                                        return Map.of(
                                                        "approach", "webflux-parallel",
                                                        "persons", persons,
                                                        "totalCount", persons.size(),
                                                        "batches", batches,
                                                        "countPerBatch", countPerBatch,
                                                        "executionTimeMs", endTime - startTime,
                                                        "initialThreadInfo", threadInfo,
                                                        "finalThreadInfo", finalThreadInfo,
                                                        "timestamp", LocalDateTime.now());
                                });
        }

        /**
         * Spring WebFlux - Lista com blocking I/O intensivo (demonstra vantagens das
         * Virtual Threads)
         */
        @GetMapping("/webflux/persons/list-intensive")
        public Mono<Map<String, Object>> getWebFluxPersonsListIntensive(
                        @RequestParam(defaultValue = "10") int count) {

                long startTime = System.currentTimeMillis();
                String threadInfo = personService.getCurrentThreadInfo();

                return personService.getPersonsReactiveListIntensive(count)
                                .map(persons -> {
                                        long endTime = System.currentTimeMillis();
                                        String finalThreadInfo = personService.getCurrentThreadInfo();

                                        return Map.of(
                                                        "approach", "webflux-list-intensive",
                                                        "persons", persons,
                                                        "count", persons.size(),
                                                        "executionTimeMs", endTime - startTime,
                                                        "initialThreadInfo", threadInfo,
                                                        "finalThreadInfo", finalThreadInfo,
                                                        "timestamp", LocalDateTime.now());
                                });
        }

        /**
         * Spring WebFlux - Informações sobre threads
         */
        @GetMapping("/webflux/thread-info")
        public Mono<Map<String, Object>> getWebFluxThreadInfo() {
                return Mono.fromCallable(() -> {
                        String threadInfo = personService.getCurrentThreadInfo();

                        return Map.of(
                                        "approach", "webflux",
                                        "threadInfo", threadInfo,
                                        "timestamp", LocalDateTime.now(),
                                        "activeThreadCount", Thread.activeCount(),
                                        "availableProcessors", Runtime.getRuntime().availableProcessors());
                });
        }
}
