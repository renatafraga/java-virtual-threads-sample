package edu.renata.fraga.java_virtual_threads_sample.model;

public record Person(
        Long id,
        String name,
        String email,
        int age,
        String city) {

    public static Person create(Long id, String name, String email, int age, String city) {
        return new Person(id, name, email, age, city);
    }
}
