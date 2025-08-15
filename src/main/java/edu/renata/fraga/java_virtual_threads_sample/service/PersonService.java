package edu.renata.fraga.java_virtual_threads_sample.service;

import edu.renata.fraga.java_virtual_threads_sample.model.Person;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.stream.IntStream;

@Service
public class PersonService {

    private static final List<String> NAMES = List.of(
            "João Silva", "Maria Santos", "Pedro Oliveira", "Ana Costa", "Carlos Ferreira",
            "Lucia Rodrigues", "Marcos Lima", "Fernanda Alves", "Roberto Souza", "Patricia Gomes",
            "Daniel Martins", "Juliana Pereira", "Ricardo Barbosa", "Camila Ribeiro", "Fernando Dias",
            "Bianca Moreira", "Gustavo Carvalho", "Leticia Nascimento", "Bruno Araújo", "Sabrina Freitas");

    private static final List<String> CITIES = List.of(
            "São Paulo", "Rio de Janeiro", "Belo Horizonte", "Salvador", "Brasília",
            "Fortaleza", "Curitiba", "Recife", "Porto Alegre", "Manaus",
            "Belém", "Goiânia", "Campinas", "São Luís", "Maceió");

    /**
     * Simula uma operação blocking mais realista (ex: consulta a banco de dados ou
     * API externa)
     */
    private void simulateBlockingOperation() {
        try {
            Thread.sleep(500); // Simula 500ms de latência - mais realista para DB/API calls
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /**
     * Simula operação blocking rápida para comparação
     */
    private void simulateQuickBlockingOperation() {
        try {
            Thread.sleep(100); // Simula 100ms de latência
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /**
     * Implementação tradicional blocking para Spring MVC
     */
    public List<Person> getPersonsBlocking(int count) {
        return IntStream.range(0, count)
                .mapToObj(this::createPersonWithDelay)
                .toList();
    }

    /**
     * Implementação com CompletableFuture para Spring MVC com Virtual Threads
     */
    public CompletableFuture<List<Person>> getPersonsAsync(int count) {
        return CompletableFuture.supplyAsync(() -> IntStream.range(0, count)
                .mapToObj(this::createPersonWithDelay)
                .toList());
    }

    /**
     * Implementação com processamento concorrente para Spring MVC
     */
    public CompletableFuture<List<Person>> getPersonsConcurrent(int batches, int countPerBatch) {
        List<CompletableFuture<List<Person>>> batchFutures = IntStream.range(0, batches)
                .mapToObj(batchIndex -> CompletableFuture
                        .supplyAsync(() -> IntStream.range(batchIndex * countPerBatch, (batchIndex + 1) * countPerBatch)
                                .mapToObj(this::createPersonWithDelay)
                                .toList()))
                .toList();

        return CompletableFuture.allOf(batchFutures.toArray(new CompletableFuture[0]))
                .thenApply(v -> batchFutures.stream()
                        .flatMap(future -> future.join().stream())
                        .toList());
    }

    /**
     * Implementação reativa para Spring WebFlux (tradicional)
     */
    public Flux<Person> getPersonsReactive(int count) {
        return Flux.range(0, count)
                .delayElements(Duration.ofMillis(50)) // Simula latência de forma não-blocking
                .map(this::createPerson);
    }

    /**
     * Implementação reativa com delay maior para comparação
     */
    public Mono<List<Person>> getPersonsReactiveList(int count) {
        return Flux.range(0, count)
                .delayElements(Duration.ofMillis(50))
                .map(this::createPerson)
                .collectList();
    }

    /**
     * Implementação reativa com processamento paralelo em batches
     */
    public Mono<List<Person>> getPersonsReactiveList(int batches, int countPerBatch) {
        return Flux.range(0, batches)
                .flatMap(batchIndex -> Flux.range(batchIndex * countPerBatch, countPerBatch)
                        .publishOn(Schedulers.parallel())
                        .map(index -> {
                            simulateBlockingOperation(); // Simula operação blocking
                            return createPerson(index);
                        }))
                .collectList();
    }

    /**
     * Implementação reativa com scheduler específico para demonstrar Virtual
     * Threads no WebFlux
     */
    public Flux<Person> getPersonsReactiveWithScheduler(int count, boolean useVirtualThreads) {
        return Flux.range(0, count)
                .publishOn(useVirtualThreads ? Schedulers.boundedElastic() : Schedulers.parallel())
                .map(index -> {
                    simulateBlockingOperation(); // Operação blocking para testar Virtual Threads
                    return createPerson(index);
                })
                .delayElements(Duration.ofMillis(10)); // Pequeno delay para evitar overhead
    }

    /**
     * Implementação reativa com blocking I/O simulado para lista
     */
    public Mono<List<Person>> getPersonsReactiveListWithScheduler(int count, boolean useVirtualThreads) {
        return Flux.range(0, count)
                .publishOn(useVirtualThreads ? Schedulers.boundedElastic() : Schedulers.parallel())
                .map(index -> {
                    simulateBlockingOperation(); // Importante: blocking operation para testar VT
                    return createPerson(index);
                })
                .collectList();
    }

    /**
     * Implementação reativa com I/O blocking mais intensivo
     */
    public Flux<Person> getPersonsReactiveBlocking(int count) {
        return Flux.range(0, count)
                .publishOn(Schedulers.boundedElastic()) // Usa scheduler adequado para blocking I/O
                .map(this::createPersonWithDelay); // Com blocking operation
    }

    /**
     * Implementação blocking com latência maior para demonstrar vantagens das
     * Virtual Threads
     */
    public List<Person> getPersonsBlockingIntensive(int count) {
        return IntStream.range(0, count)
                .mapToObj(this::createPersonWithIntensiveDelay)
                .toList();
    }

    /**
     * Implementação blocking rápida para comparação
     */
    public List<Person> getPersonsBlockingQuick(int count) {
        return IntStream.range(0, count)
                .mapToObj(this::createPersonWithQuickDelay)
                .toList();
    }

    /**
     * Implementação reativa com blocking I/O intensivo para lista
     */
    public Mono<List<Person>> getPersonsReactiveListIntensive(int count) {
        return Flux.range(0, count)
                .publishOn(Schedulers.boundedElastic()) // Importante: usar boundedElastic para blocking I/O
                .map(this::createPersonWithIntensiveDelay) // Com blocking operation mais intensiva
                .collectList();
    }

    private Person createPersonWithDelay(int index) {
        simulateQuickBlockingOperation(); // Simula operação blocking rápida (100ms)
        return createPerson(index);
    }

    private Person createPersonWithIntensiveDelay(int index) {
        simulateBlockingOperation(); // Simula operação blocking mais intensiva (500ms)
        return createPerson(index);
    }

    private Person createPersonWithQuickDelay(int index) {
        simulateQuickBlockingOperation(); // Simula operação blocking rápida (100ms)
        return createPerson(index);
    }

    private Person createPerson(int index) {
        return Person.create(
                (long) index,
                NAMES.get(index % NAMES.size()),
                generateEmail(index),
                20 + (index % 50), // Idade entre 20 e 69
                CITIES.get(index % CITIES.size()));
    }

    private String generateEmail(int index) {
        String name = NAMES.get(index % NAMES.size())
                .toLowerCase()
                .replace(" ", ".");
        return name + "@example.com";
    }

    /**
     * Método para obter estatísticas do thread atual
     */
    public String getCurrentThreadInfo() {
        Thread currentThread = Thread.currentThread();
        return String.format("Thread: %s, Virtual: %s, ThreadId: %s",
                currentThread.getName(),
                currentThread.isVirtual(),
                currentThread.threadId());
    }

    /**
     * Método para obter informações detalhadas sobre schedulers
     */
    public String getSchedulerInfo() {
        return String.format("BoundedElastic pools: %d, Parallel pools: %d",
                Schedulers.boundedElastic().hashCode(),
                Schedulers.parallel().hashCode());
    }
}
