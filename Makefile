# =============================================================================
# Virtual Threads Performance Benchmark - Makefile Simplificado
# =============================================================================

# Configurações
SHELL := /bin/zsh
.DEFAULT_GOAL := help
.PHONY: help build benchmark benchmark-fast benchmark-load report clean-reports

# Cores para output
CYAN := \033[0;36m
EMERALD := \033[38;5;46m
AMBER := \033[38;5;214m
RED := \033[0;31m
SILVER := \033[38;5;245m
NC := \033[0m

# Variáveis
JAR_FILE := build/libs/java-virtual-threads-sample-0.0.1-SNAPSHOT.jar
BENCHMARK_SCRIPT := ./performance-benchmark.sh
LATEST_REPORT := $(shell ls -t performance-report-*.txt 2>/dev/null | head -1)

# =============================================================================
# AJUDA
# =============================================================================

## 📋 Exibir comandos disponíveis
help:
	@echo "$(CYAN)🚀 Virtual Threads Performance Benchmark$(NC)"
	@echo "=============================================="
	@echo ""
	@echo "$(EMERALD)📊 BENCHMARKS:$(NC)"
	@echo "  make benchmark      - Benchmark completo (20 requests, 100 concurrent)"
	@echo "  make benchmark-fast - Benchmark rápido (10 requests, 50 concurrent)"
	@echo "  make benchmark-load - Benchmark alta carga (30 requests, 200 concurrent)"
	@echo ""
	@echo "$(AMBER)📄 RELATÓRIOS:$(NC)"
	@echo "  make report         - Visualizar último relatório"
	@echo "  make clean-reports  - Limpar relatórios antigos"
	@echo ""
	@echo "$(SILVER)🔧 PREPARAÇÃO:$(NC)"
	@echo "  make build          - Compilar o projeto"

# =============================================================================
# BUILD
# =============================================================================

## 🔨 Compilar o projeto
build:
	@echo "$(CYAN)🔨 Compilando projeto...$(NC)"
	@./gradlew clean build -x test
	@echo "$(EMERALD)✅ Projeto compilado$(NC)"

# =============================================================================
# BENCHMARKS
# =============================================================================

## 📊 Benchmark completo (configuração padrão)
benchmark: build
	@echo "$(CYAN)📊 Executando benchmark completo...$(NC)"
	@echo "$(SILVER)⚙️  Configuração: 20 requests, 100 concurrent$(NC)"
	@$(BENCHMARK_SCRIPT) simple
	@make _show-summary

## ⚡ Benchmark rápido (menos requisições)
benchmark-fast: build
	@echo "$(CYAN)⚡ Executando benchmark rápido...$(NC)"
	@echo "$(SILVER)⚙️  Configuração: 10 requests, 50 concurrent$(NC)"
	@TEST_REQUESTS=10 CONCURRENT_REQUESTS=50 $(BENCHMARK_SCRIPT) simple
	@make _show-summary

## 🚀 Benchmark com alta carga
benchmark-load: build
	@echo "$(CYAN)🚀 Executando benchmark de alta carga...$(NC)"
	@echo "$(SILVER)⚙️  Configuração: 30 requests, 200 concurrent$(NC)"
	@TEST_REQUESTS=30 CONCURRENT_REQUESTS=200 $(BENCHMARK_SCRIPT) simple
	@make _show-summary

# =============================================================================
# RELATÓRIOS E LOGS
# =============================================================================

## 📄 Visualizar último relatório gerado
report:
	@if [ -z "$(LATEST_REPORT)" ]; then \
		echo "$(RED)❌ Nenhum relatório encontrado$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)📄 Último relatório: $(LATEST_REPORT)$(NC)"
	@echo "$(SILVER)════════════════════════════════════════$(NC)"
	@cat $(LATEST_REPORT)

## 📋 Ver logs da aplicação
logs:
	@echo "$(CYAN)📋 Logs das aplicações:$(NC)"
	@echo "$(SILVER)════════════════════════════════════════$(NC)"
	@for log in /tmp/app-*.log; do \
		if [ -f "$$log" ]; then \
			echo "$(AMBER)📄 $$log:$(NC)"; \
			tail -20 "$$log" 2>/dev/null || echo "$(SILVER)  (vazio)$(NC)"; \
			echo ""; \
		fi; \
	done

## 🗑️ Limpar relatórios antigos (manter últimos 5)
clean-reports:
	@echo "$(SILVER)🗑️  Limpando relatórios antigos...$(NC)"
	@ls -t performance-report-*.txt 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
	@ls -1 performance-report-*.txt 2>/dev/null | wc -l | xargs -I {} echo "$(GREEN)✅ Mantidos {} relatórios$(NC)"

# =============================================================================
# UTILITÁRIOS
# =============================================================================

## 📊 Status do projeto
status:
	@echo "$(CYAN)📊 Status do Projeto$(NC)"
	@echo "$(SILVER)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)🏗️  Build:$(NC)"
	@if [ -f "$(JAR_FILE)" ]; then \
		echo "  ✅ JAR compilado: $(JAR_FILE)"; \
		echo "  📅 Modificado: $$(stat -f "%Sm" $(JAR_FILE))"; \
	else \
		echo "  ❌ JAR não encontrado - execute 'make build'"; \
	fi
	@echo ""
	@echo "$(AMBER)📄 Relatórios:$(NC)"
	@ls -t performance-report-*.txt 2>/dev/null | head -3 | while read report; do \
		echo "  📋 $$report"; \
	done || echo "  📝 Nenhum relatório encontrado"
	@echo ""
	@echo "$(CYAN)🔧 Dependências:$(NC)"
	@printf "  curl: "; command -v curl &> /dev/null && echo "✅" || echo "❌"
	@printf "  jq: "; command -v jq &> /dev/null && echo "✅" || echo "❌"
	@printf "  bc: "; command -v bc &> /dev/null && echo "✅" || echo "❌"
	@printf "  gdate: "; command -v gdate &> /dev/null && echo "✅" || echo "❌"
	@echo ""
	@echo "$(PURPLE)🏃 Processos ativos:$(NC)"
	@pgrep -f "java-virtual-threads-sample" | wc -l | xargs -I {} echo "  🔄 {} aplicações rodando"

## 💀 Matar aplicações em execução
kill-apps:
	@echo "$(SILVER)💀 Matando aplicações em execução...$(NC)"
	@pkill -f "java-virtual-threads-sample" 2>/dev/null || echo "$(SILVER)  Nenhuma aplicação rodando$(NC)"
	@sleep 2
	@echo "$(GREEN)✅ Aplicações finalizadas$(NC)"

# =============================================================================
# TARGETS INTERNOS
# =============================================================================

## Target interno para mostrar resumo após benchmark
_show-summary:
	@echo ""
	@echo "$(GREEN)✨ BENCHMARK CONCLUÍDO!$(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════════$(NC)"
	@if [ -n "$(LATEST_REPORT)" ]; then \
		echo "$(AMBER)📄 Relatório: $(LATEST_REPORT)$(NC)"; \
		echo "$(SILVER)💡 Use 'make report' para visualizar$(NC)"; \
	fi
	@echo "$(CYAN)═══════════════════════════════════════════════════════════════$(NC)"

# =============================================================================
# TARGETS PARA DESENVOLVIMENTO
# =============================================================================

## 🔄 Watch mode - recompila automaticamente
watch:
	@echo "$(CYAN)🔄 Modo watch ativado - recompilando automaticamente...$(NC)"
	@echo "$(SILVER)💡 Pressione Ctrl+C para sair$(NC)"
	@./gradlew build --continuous -x test

## 🐛 Executar aplicação em modo debug
debug:
	@echo "$(CYAN)🐛 Iniciando aplicação em modo debug...$(NC)"
	@echo "$(SILVER)🔌 Debug port: 5005$(NC)"
	@java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 \
		-jar $(JAR_FILE) --spring.profiles.active=mvc-traditional

## 📈 Benchmark com profiler
profile: build
	@echo "$(CYAN)📈 Executando benchmark com profiler...$(NC)"
	@echo "$(SILVER)⚠️  Requer VisualVM ou JProfiler$(NC)"
	@JAVA_OPTS="-XX:+FlightRecorder -XX:StartFlightRecording=duration=60s,filename=benchmark.jfr" \
		$(BENCHMARK_SCRIPT) simple

# =============================================================================
# VALIDAÇÕES
# =============================================================================

## ✅ Verificar se o ambiente está pronto
check-env: 
	@echo "$(CYAN)✅ Verificando ambiente...$(NC)"
	@command -v java &> /dev/null || (echo "$(RED)❌ Java não encontrado$(NC)" && exit 1)
	@java -version 2>&1 | grep -q "21\." || echo "$(AMBER)⚠️  Java 21 recomendado$(NC)"
	@command -v ./gradlew &> /dev/null || (echo "$(RED)❌ Gradle wrapper não encontrado$(NC)" && exit 1)
	@[ -f "$(BENCHMARK_SCRIPT)" ] || (echo "$(RED)❌ Script de benchmark não encontrado$(NC)" && exit 1)
	@echo "$(GREEN)✅ Ambiente configurado corretamente$(NC)"

# Garantir que o script tenha permissão de execução
$(BENCHMARK_SCRIPT):
	@chmod +x $(BENCHMARK_SCRIPT)
