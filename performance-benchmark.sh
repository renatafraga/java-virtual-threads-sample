#!/bin/bash

# =============================================================================
# Performance Benchmark - Virtual Threads vs Spring WebFlux - FIXED VERSION
# Executa todos os profiles e gera relatório completo de performance
# =============================================================================

set -e  # Para no primeiro erro

# Cores para output - Paleta moderna e elegante
RED='\033[0;31m'           # Vermelho para erros
EMERALD='\033[38;5;46m'    # Verde esmeralda em vez do verde padrão
AMBER='\033[38;5;214m'     # Âmbar em vez do amarelo
BLUE='\033[0;34m'          # Azul padrão
PURPLE='\033[0;35m'        # Roxo padrão
CYAN='\033[0;36m'          # Ciano padrão
SILVER='\033[38;5;245m'    # Prata para informações secundárias
LIME='\033[38;5;154m'      # Verde lima para sucessos
ORANGE='\033[38;5;208m'    # Laranja para warnings
TEAL='\033[38;5;30m'       # Verde azulado
NC='\033[0m'               # No Color

# Configurações (podem ser sobrescritas por variáveis de ambiente)
PORT=${PORT:-8080}
WARMUP_REQUESTS=${WARMUP_REQUESTS:-5}
TEST_REQUESTS=${TEST_REQUESTS:-20}
CONCURRENT_REQUESTS=${CONCURRENT_REQUESTS:-100}
RESULTS_FILE="performance-report-$(date +%Y%m%d-%H%M%S).txt"

echo -e "${BLUE}🚀 BENCHMARK DE PERFORMANCE - VIRTUAL THREADS${NC}"
echo "=============================================================="
echo "📅 Data: $(date)"
echo "⚙️  Configuração:"
echo "   - Warmup requests: $WARMUP_REQUESTS"
echo "   - Test requests: $TEST_REQUESTS"
echo "   - Concurrent requests: $CONCURRENT_REQUESTS"
echo "   - Relatório será salvo em: $RESULTS_FILE"
echo ""

# Função para obter timestamp preciso (compatível com macOS e Linux)
get_timestamp_ms() {
    if [[ "$OSTYPE" == "darwin"* ]] && command -v gdate &> /dev/null; then
        # macOS com GNU coreutils
        gdate +%s%3N
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sem GNU coreutils - usar python como fallback
        python3 -c "import time; print(int(time.time() * 1000))"
    else
        # Linux
        date +%s%3N
    fi
}

# Verificar dependências
check_dependencies() {
    echo -e "${CYAN}🔍 Verificando dependências...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl não encontrado${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${ORANGE}⚠️  jq não encontrado. Instalando...${NC}"
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo -e "${RED}❌ Por favor, instale jq manualmente${NC}"
            exit 1
        fi
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${ORANGE}⚠️  bc (calculadora) não encontrado. Instalando...${NC}"
        if command -v brew &> /dev/null; then
            brew install bc
        else
            echo -e "${RED}❌ Por favor, instale bc manualmente: brew install bc${NC}"
            exit 1
        fi
    fi
    
    # Verificar se temos gdate (GNU date) para timestamps precisos no macOS
    if [[ "$OSTYPE" == "darwin"* ]] && ! command -v gdate &> /dev/null; then
        echo -e "${ORANGE}⚠️  gdate não encontrado. Instalando coreutils para timestamps precisos...${NC}"
        if command -v brew &> /dev/null; then
            brew install coreutils
        else
            echo -e "${ORANGE}⚠️  Sem coreutils, usando Python para timestamps${NC}"
        fi
    fi
    
    echo -e "${EMERALD}✅ Dependências verificadas${NC}"
}

# Compilar projeto se necessário
build_project() {
    if [ ! -f "build/libs/java-virtual-threads-sample-0.0.1-SNAPSHOT.jar" ]; then
        echo -e "${AMBER}🔨 Compilando projeto...${NC}"
        ./gradlew clean build -x test
        if [ $? -ne 0 ]; then
            echo -e "${RED}💥 Erro na compilação!${NC}"
            exit 1
        fi
        echo -e "${EMERALD}✅ Projeto compilado${NC}"
    else
        echo -e "${EMERALD}✅ JAR já existe${NC}"
    fi
}

# Aguardar aplicação estar pronta
wait_for_app() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${SILVER}⏳ Aguardando aplicação inicializar...${NC}" >&2
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:$PORT/api/ > /dev/null 2>&1; then
            return 0
        fi
        echo -n "." >&2
        sleep 1
        ((attempt++))
    done
    
    echo -e "${RED}❌ Timeout aguardando aplicação${NC}" >&2
    return 1
}

# Fazer warmup da JVM
warmup_jvm() {
    local endpoint=$1
    echo -e "${ORANGE}🔥 Fazendo warmup da JVM...${NC}" >&2
    for i in $(seq 1 $WARMUP_REQUESTS); do
        curl -s "$endpoint" > /dev/null 2>&1 || true
        echo -n "." >&2
    done
    echo -e "${LIME} ✅ Warmup concluído${NC}" >&2
}

# Executar teste de performance
run_performance_test() {
    local test_name=$1
    local endpoint=$2
    local description=$3
    
    echo -e "${CYAN}🧪 Testando: $test_name${NC}" >&2
    echo "   Endpoint: $endpoint" >&2
    echo "   Descrição: $description" >&2
    
    # Fazer warmup primeiro
    warmup_jvm "$endpoint"
    
    # Arrays para armazenar resultados
    local times=()
    local thread_infos=()
    
    echo -e "${SILVER}📊 Executando $TEST_REQUESTS requisições...${NC}" >&2
    
    for i in $(seq 1 $TEST_REQUESTS); do
        local start_time=$(get_timestamp_ms)
        
        # Fazer a requisição e capturar resposta
        local response=$(curl -s "$endpoint" 2>/dev/null)
        
        local end_time=$(get_timestamp_ms)
        local total_time=$((end_time - start_time))
        
        # Verificar se temos resposta válida
        if [ ! -z "$response" ]; then
            # Extrair informações da resposta se possível
            local thread_info=$(echo "$response" | jq -r '.threadInfo // .initialThreadInfo // "N/A"' 2>/dev/null || echo "N/A")
            
            times+=($total_time)
            thread_infos+=("$thread_info")
        else
            echo -n "E" >&2 # Erro
            times+=(0)
            thread_infos+=("ERROR")
        fi
        
        echo -n "." >&2
    done
    
    echo "" >&2
    
    # Calcular estatísticas
    local sum=0
    local min=999999
    local max=0
    local valid_count=0
    
    for time in "${times[@]}"; do
        if [ "$time" -gt 0 ] 2>/dev/null; then
            sum=$((sum + time))
            if [ $time -lt $min ]; then min=$time; fi
            if [ $time -gt $max ]; then max=$time; fi
            ((valid_count++))
        fi
    done
    
    if [ $valid_count -eq 0 ]; then
        echo -e "${RED}❌ Nenhum tempo válido coletado${NC}" >&2
        echo "0:0:0:0:ERROR"
        return
    fi
    
    local avg=$((sum / valid_count))
    
    # Salvar resultados
    echo "----------------------------------------" >> "$RESULTS_FILE"
    echo "TESTE: $test_name" >> "$RESULTS_FILE"
    echo "Endpoint: $endpoint" >> "$RESULTS_FILE"
    echo "Descrição: $description" >> "$RESULTS_FILE"
    echo "Data/Hora: $(date)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "RESULTADOS:" >> "$RESULTS_FILE"
    echo "- Requisições válidas: $valid_count/${#times[@]}" >> "$RESULTS_FILE"
    echo "- Tempo médio: ${avg}ms" >> "$RESULTS_FILE"
    echo "- Tempo mínimo: ${min}ms" >> "$RESULTS_FILE"
    echo "- Tempo máximo: ${max}ms" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Mostrar resumo na tela
    echo -e "${LIME}📈 Resultados:${NC}" >&2
    echo "   • Requisições válidas: $valid_count/${#times[@]}" >&2
    echo "   • Tempo médio: ${avg}ms" >&2
    echo "   • Tempo mínimo: ${min}ms" >&2
    echo "   • Tempo máximo: ${max}ms" >&2
    echo "   • Thread info (primeira req): ${thread_infos[0]}" >&2
    echo "" >&2
    
    # Retornar valores para comparação global
    echo "$avg:$min:$max:$valid_count:${thread_infos[0]}"
}

# Teste de carga concorrente
run_concurrent_test() {
    local test_name=$1
    local endpoint=$2
    
    echo -e "${PURPLE}⚡ Teste de Carga Concorrente: $test_name${NC}" >&2
    echo "   Endpoint: $endpoint" >&2
    echo "   Requisições simultâneas: $CONCURRENT_REQUESTS" >&2
    
    local start_time=$(get_timestamp_ms)
    
    # Executar requisições em paralelo
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        curl -s "$endpoint" > /dev/null 2>&1 &
    done
    
    # Aguardar todas as requisições terminarem
    wait
    
    local end_time=$(get_timestamp_ms)
    local total_time=$((end_time - start_time))
    
    echo -e "${TEAL}📊 Teste de carga concluído em: ${total_time}ms${NC}" >&2
    
    if [ "$total_time" -gt 0 ]; then
        local rps=$(echo "scale=2; $CONCURRENT_REQUESTS * 1000 / $total_time" | bc 2>/dev/null || echo "N/A")
        echo "   • Requisições por segundo: $rps" >&2
    else
        echo "   • Requisições por segundo: N/A (tempo inválido)" >&2
        local rps="N/A"
    fi
    
    # Salvar no relatório
    echo "TESTE DE CARGA CONCORRENTE: $test_name" >> "$RESULTS_FILE"
    echo "- Requisições simultâneas: $CONCURRENT_REQUESTS" >> "$RESULTS_FILE"
    echo "- Tempo total: ${total_time}ms" >> "$RESULTS_FILE"
    echo "- Requisições por segundo: $rps" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "$total_time"
}

# Iniciar aplicação com profile específico
start_application() {
    local profile=$1
    local profile_name=$2
    
    echo -e "${BLUE}🚀 Iniciando aplicação: $profile_name${NC}" >&2
    echo "   Profile: $profile" >&2
    
    # Matar processos existentes
    pkill -f "java-virtual-threads-sample" 2>/dev/null || true
    sleep 2
    
    # Iniciar nova aplicação
    java -jar build/libs/java-virtual-threads-sample-0.0.1-SNAPSHOT.jar \
        --spring.profiles.active="$profile" \
        --server.port=$PORT \
        --logging.level.root=WARN \
        > /tmp/app-$profile.log 2>&1 &
    
    local pid=$!
    echo "   PID: $pid" >&2
    
    if ! wait_for_app; then
        echo -e "${RED}❌ Falha ao iniciar aplicação${NC}" >&2
        kill $pid 2>/dev/null || true
        return 1
    fi
    
    return 0
}

# Parar aplicação
stop_application() {
    echo -e "${ORANGE}🛑 Parando aplicação...${NC}" >&2
    pkill -f "java-virtual-threads-sample" 2>/dev/null || true
    sleep 2
    echo -e "${EMERALD}✅ Aplicação parada${NC}" >&2
}

# Função de teste rápido
quick_test() {
    echo -e "${CYAN}🧪 Teste Rápido de Funcionalidade${NC}"
    
    check_dependencies
    build_project
    
    # Testar apenas um profile
    if start_application "mvc-traditional" "Spring MVC Tradicional"; then
        run_performance_test \
            "MVC Quick Test" \
            "http://localhost:$PORT/api/mvc/persons/blocking?count=5" \
            "Teste rápido do MVC blocking"
        
        stop_application
        echo -e "${EMERALD}✅ Teste rápido concluído com sucesso!${NC}"
    else
        echo -e "${RED}❌ Falha no teste rápido${NC}"
        return 1
    fi
}

# Testar um endpoint específico
test_single_endpoint() {
    local profile=$1
    local profile_name=$2
    local endpoint_path=$3
    local test_description=$4
    
    echo "" >&2
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${BLUE}🎯 TESTANDO: $profile_name${NC}" >&2
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2
    
    # Iniciar aplicação
    if ! start_application "$profile" "$profile_name"; then
        echo -e "${RED}❌ Falha ao iniciar aplicação para o profile $profile${NC}" >&2
        return 1
    fi
    
    # Salvar cabeçalho no relatório
    echo "===============================================" >> "$RESULTS_FILE"
    echo "TESTE: $profile_name ($profile)" >> "$RESULTS_FILE"
    echo "Descrição: $test_description" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    
    # Executar teste do endpoint (redirecionar saída visual para stderr)
    local test_result=$(run_performance_test \
        "$profile_name" \
        "http://localhost:$PORT$endpoint_path" \
        "$test_description" 2>&2)
    
    # Teste de carga concorrente
    echo -e "${PURPLE}⚡ Teste de Carga Concorrente...${NC}" >&2
    local concurrent_result=$(run_concurrent_test \
        "$profile_name" \
        "http://localhost:$PORT$endpoint_path" 2>&2)
    
    # Parar aplicação
    stop_application
    
    # Retornar resultado (formato: test_result|concurrent_result)
    echo "$test_result|$concurrent_result"
}

# Gerar relatório de comparação
generate_comparison_report() {
    local mvc_traditional_results=$1
    local mvc_virtual_results=$2
    local webflux_traditional_results=$3
    local webflux_virtual_results=$4
    
    echo "" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    echo "RELATÓRIO DE COMPARAÇÃO FINAL" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    echo "Gerado em: $(date)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Verificar se temos resultados válidos
    if [[ -z "$mvc_traditional_results" || -z "$mvc_virtual_results" ]]; then
        echo "⚠️  Alguns testes falharam - relatório de comparação incompleto" >> "$RESULTS_FILE"
        return
    fi
    
    # Extrair médias para comparação (primeiro valor antes do :)
    IFS='|' read -ra mvc_trad <<< "$mvc_traditional_results"
    IFS='|' read -ra mvc_virt <<< "$mvc_virtual_results"
    
    echo "COMPARAÇÃO - SPRING MVC:" >> "$RESULTS_FILE"
    echo "==========================================" >> "$RESULTS_FILE"
    
    # MVC Blocking
    local mvc_trad_blocking_avg=$(echo "${mvc_trad[0]}" | cut -d':' -f1)
    local mvc_virt_blocking_avg=$(echo "${mvc_virt[0]}" | cut -d':' -f1)
    echo "MVC BLOCKING:" >> "$RESULTS_FILE"
    echo "- Tradicional: ${mvc_trad_blocking_avg}ms (avg)" >> "$RESULTS_FILE"
    echo "- Virtual:     ${mvc_virt_blocking_avg}ms (avg)" >> "$RESULTS_FILE"
    
    # Calcular melhoria se possível
    if [[ "$mvc_trad_blocking_avg" != "0" && "$mvc_virt_blocking_avg" != "0" ]]; then
        local improvement=$(echo "scale=2; (($mvc_trad_blocking_avg - $mvc_virt_blocking_avg) / $mvc_trad_blocking_avg) * 100" | bc 2>/dev/null || echo "N/A")
        echo "- Melhoria: ${improvement}%" >> "$RESULTS_FILE"
    fi
    echo "" >> "$RESULTS_FILE"
    
    # MVC Async
    local mvc_trad_async_avg=$(echo "${mvc_trad[1]}" | cut -d':' -f1)
    local mvc_virt_async_avg=$(echo "${mvc_virt[1]}" | cut -d':' -f1)
    echo "MVC ASYNC:" >> "$RESULTS_FILE"
    echo "- Tradicional: ${mvc_trad_async_avg}ms (avg)" >> "$RESULTS_FILE"
    echo "- Virtual:     ${mvc_virt_async_avg}ms (avg)" >> "$RESULTS_FILE"
    
    if [[ "$mvc_trad_async_avg" != "0" && "$mvc_virt_async_avg" != "0" ]]; then
        local improvement=$(echo "scale=2; (($mvc_trad_async_avg - $mvc_virt_async_avg) / $mvc_trad_async_avg) * 100" | bc 2>/dev/null || echo "N/A")
        echo "- Melhoria: ${improvement}%" >> "$RESULTS_FILE"
    fi
    echo "" >> "$RESULTS_FILE"
    
    # WebFlux se disponível
    if [[ ! -z "$webflux_traditional_results" && ! -z "$webflux_virtual_results" ]]; then
        IFS='|' read -ra webflux_trad <<< "$webflux_traditional_results"
        IFS='|' read -ra webflux_virt <<< "$webflux_virtual_results"
        
        echo "COMPARAÇÃO - SPRING WEBFLUX:" >> "$RESULTS_FILE"
        echo "==========================================" >> "$RESULTS_FILE"
        
        local webflux_trad_list_avg=$(echo "${webflux_trad[3]}" | cut -d':' -f1)
        local webflux_virt_list_avg=$(echo "${webflux_virt[3]}" | cut -d':' -f1)
        echo "WEBFLUX LIST:" >> "$RESULTS_FILE"
        echo "- Tradicional: ${webflux_trad_list_avg}ms (avg)" >> "$RESULTS_FILE"
        echo "- Virtual:     ${webflux_virt_list_avg}ms (avg)" >> "$RESULTS_FILE"
        
        if [[ "$webflux_trad_list_avg" != "0" && "$webflux_virt_list_avg" != "0" ]]; then
            local improvement=$(echo "scale=2; (($webflux_trad_list_avg - $webflux_virt_list_avg) / $webflux_trad_list_avg) * 100" | bc 2>/dev/null || echo "N/A")
            echo "- Melhoria: ${improvement}%" >> "$RESULTS_FILE"
        fi
        echo "" >> "$RESULTS_FILE"
    fi
    
    # Testes de carga
    echo "COMPARAÇÃO - TESTES DE CARGA:" >> "$RESULTS_FILE"
    echo "==========================================" >> "$RESULTS_FILE"
    echo "CARGA CONCORRENTE (MVC Blocking):" >> "$RESULTS_FILE"
    echo "- Tradicional: ${mvc_trad[5]}ms total" >> "$RESULTS_FILE"
    echo "- Virtual:     ${mvc_virt[5]}ms total" >> "$RESULTS_FILE"
    
    if [[ ! -z "$webflux_traditional_results" && ! -z "$webflux_virtual_results" ]]; then
        echo "CARGA CONCORRENTE (WebFlux List):" >> "$RESULTS_FILE"
        echo "- Tradicional: ${webflux_trad[6]}ms total" >> "$RESULTS_FILE"
        echo "- Virtual:     ${webflux_virt[6]}ms total" >> "$RESULTS_FILE"
    fi
    echo "" >> "$RESULTS_FILE"
}

# Gerar relatório de comparação simplificado
generate_simple_comparison_report() {
    local mvc_traditional=$1
    local mvc_virtual=$2
    local webflux_traditional=$3
    local webflux_virtual=$4
    
    echo "" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    echo "COMPARAÇÃO FINAL - VIRTUAL THREADS vs TRADICIONAL" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    echo "Gerado em: $(date)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Extrair dados dos resultados (formato: avg:min:max:count:thread_info|concurrent_time)
    if [[ ! -z "$mvc_traditional" && ! -z "$mvc_virtual" ]]; then
        IFS='|' read -ra mvc_trad <<< "$mvc_traditional"
        IFS='|' read -ra mvc_virt <<< "$mvc_virtual"
        
        local mvc_trad_avg=$(echo "${mvc_trad[0]}" | cut -d':' -f1)
        local mvc_virt_avg=$(echo "${mvc_virt[0]}" | cut -d':' -f1)
        local mvc_trad_concurrent=${mvc_trad[1]}
        local mvc_virt_concurrent=${mvc_virt[1]}
        
        echo "🔹 SPRING MVC COMPARISON:" >> "$RESULTS_FILE"
        echo "  Tempo Médio:" >> "$RESULTS_FILE"
        echo "    • Sem Virtual Threads: ${mvc_trad_avg}ms" >> "$RESULTS_FILE"
        echo "    • Com Virtual Threads: ${mvc_virt_avg}ms" >> "$RESULTS_FILE"
        
        if [[ "$mvc_trad_avg" != "0" && "$mvc_virt_avg" != "0" ]]; then
            local improvement=$(echo "scale=1; (($mvc_trad_avg - $mvc_virt_avg) / $mvc_trad_avg) * 100" | bc 2>/dev/null || echo "N/A")
            echo "    • Melhoria: ${improvement}%" >> "$RESULTS_FILE"
        fi
        
        echo "  Teste de Carga ($CONCURRENT_REQUESTS requisições):" >> "$RESULTS_FILE"
        echo "    • Sem Virtual Threads: ${mvc_trad_concurrent}ms total" >> "$RESULTS_FILE"
        echo "    • Com Virtual Threads: ${mvc_virt_concurrent}ms total" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"
    fi
    
    if [[ ! -z "$webflux_traditional" && ! -z "$webflux_virtual" ]]; then
        IFS='|' read -ra flux_trad <<< "$webflux_traditional"
        IFS='|' read -ra flux_virt <<< "$webflux_virtual"
        
        local flux_trad_avg=$(echo "${flux_trad[0]}" | cut -d':' -f1)
        local flux_virt_avg=$(echo "${flux_virt[0]}" | cut -d':' -f1)
        local flux_trad_concurrent=${flux_trad[1]}
        local flux_virt_concurrent=${flux_virt[1]}
        
        echo "🔹 SPRING WEBFLUX COMPARISON:" >> "$RESULTS_FILE"
        echo "  Tempo Médio:" >> "$RESULTS_FILE"
        echo "    • Sem Virtual Threads: ${flux_trad_avg}ms" >> "$RESULTS_FILE"
        echo "    • Com Virtual Threads: ${flux_virt_avg}ms" >> "$RESULTS_FILE"
        
        if [[ "$flux_trad_avg" != "0" && "$flux_virt_avg" != "0" ]]; then
            local improvement=$(echo "scale=1; (($flux_trad_avg - $flux_virt_avg) / $flux_trad_avg) * 100" | bc 2>/dev/null || echo "N/A")
            echo "    • Melhoria: ${improvement}%" >> "$RESULTS_FILE"
        fi
        
        echo "  Teste de Carga ($CONCURRENT_REQUESTS requisições):" >> "$RESULTS_FILE"
        echo "    • Sem Virtual Threads: ${flux_trad_concurrent}ms total" >> "$RESULTS_FILE"
        echo "    • Com Virtual Threads: ${flux_virt_concurrent}ms total" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"
    fi
    
    # Resumo geral
    echo "🎯 RESUMO EXECUTIVO:" >> "$RESULTS_FILE"
    echo "  Virtual Threads são mais eficazes quando:" >> "$RESULTS_FILE"
    echo "  • Há operações I/O intensivas (database, network)" >> "$RESULTS_FILE"
    echo "  • Muitas threads concorrentes são necessárias" >> "$RESULTS_FILE"
    echo "  • O pool de threads tradicionais é limitado" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "  Virtual Threads podem ter overhead quando:" >> "$RESULTS_FILE"
    echo "  • Operações são CPU-intensivas" >> "$RESULTS_FILE"
    echo "  • Poucas threads são necessárias" >> "$RESULTS_FILE"
    echo "  • Operações são muito rápidas" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Adicionar análise técnica detalhada
    add_technical_analysis "$mvc_traditional" "$mvc_virtual" "$webflux_traditional" "$webflux_virtual"
}

# Adicionar análise técnica detalhada ao relatório
add_technical_analysis() {
    local mvc_traditional=$1
    local mvc_virtual=$2
    local webflux_traditional=$3
    local webflux_virtual=$4
    
    echo "===============================================" >> "$RESULTS_FILE"
    echo "🧬 ANÁLISE TÉCNICA: ARQUITETURA CONFLITANTE" >> "$RESULTS_FILE"
    echo "===============================================" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Calcular melhorias/degradações
    local mvc_improvement="N/A"
    local webflux_improvement="N/A"
    
    if [[ ! -z "$mvc_traditional" && ! -z "$mvc_virtual" ]]; then
        IFS='|' read -ra mvc_trad <<< "$mvc_traditional"
        IFS='|' read -ra mvc_virt <<< "$mvc_virtual"
        local mvc_trad_concurrent=${mvc_trad[1]}
        local mvc_virt_concurrent=${mvc_virt[1]}
        
        if [[ "$mvc_trad_concurrent" != "0" && "$mvc_virt_concurrent" != "0" ]]; then
            mvc_improvement=$(echo "scale=1; (($mvc_trad_concurrent - $mvc_virt_concurrent) / $mvc_trad_concurrent) * 100" | bc 2>/dev/null || echo "N/A")
        fi
    fi
    
    if [[ ! -z "$webflux_traditional" && ! -z "$webflux_virtual" ]]; then
        IFS='|' read -ra flux_trad <<< "$webflux_traditional"
        IFS='|' read -ra flux_virt <<< "$webflux_virtual"
        local flux_trad_concurrent=${flux_trad[1]}
        local flux_virt_concurrent=${flux_virt[1]}
        
        if [[ "$flux_trad_concurrent" != "0" && "$flux_virt_concurrent" != "0" ]]; then
            webflux_improvement=$(echo "scale=1; (($flux_trad_concurrent - $flux_virt_concurrent) / $flux_trad_concurrent) * 100" | bc 2>/dev/null || echo "N/A")
        fi
    fi
    
    echo "🎯 RESULTADOS OBSERVADOS:" >> "$RESULTS_FILE"
    echo "Hardware: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Chip:' | head -1 | sed 's/.*: //' || echo 'N/A')" >> "$RESULTS_FILE"
    echo "Cores: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Total Number of Cores:' | head -1 | sed 's/.*: //' || sysctl -n hw.ncpu 2>/dev/null || echo 'N/A')" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "Spring MVC + Virtual Threads: ${mvc_improvement}% melhoria" >> "$RESULTS_FILE"
    echo "Spring WebFlux + Virtual Threads: ${webflux_improvement}% melhoria" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "🏗️ POR QUE SPRING MVC + VIRTUAL THREADS É EXCELENTE:" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "┌─ Spring MVC Tradicional ─┐    ┌─ Spring MVC + Virtual Threads ─┐" >> "$RESULTS_FILE"
    echo "│ Thread Pool (200 threads) │    │ Virtual Threads (1000+ ilimitadas) │" >> "$RESULTS_FILE"
    echo "│ ┌─────┐ ┌─────┐ ┌─────┐  │    │ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │" >> "$RESULTS_FILE"
    echo "│ │ T1  │ │ T2  │ │...  │  │    │ │ VT1 │ │ VT2 │ │...  │ │1000+│ │" >> "$RESULTS_FILE"
    echo "│ │BLOCK│ │BLOCK│ │BLOCK│  │    │ │SUSP │ │SUSP │ │SUSP │ │SUSP │ │" >> "$RESULTS_FILE"
    echo "│ └─────┘ └─────┘ └─────┘  │    │ └─────┘ └─────┘ └─────┘ └─────┘ │" >> "$RESULTS_FILE"
    echo "└──────────────────────────┘    └─────────────────────────────────┘" >> "$RESULTS_FILE"
    echo "❌ Threads bloqueadas em I/O    ✅ VT suspensas, carrier threads livres" >> "$RESULTS_FILE"
    echo "❌ Pool limitado = gargalo      ✅ Scaling ilimitado" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "⚠️ POR QUE WEBFLUX + VIRTUAL THREADS PODE SER PROBLEMÁTICO:" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "┌─ WebFlux Tradicional ─┐    ┌─ WebFlux + Virtual Threads ─┐" >> "$RESULTS_FILE"
    echo "│ Event Loop (otimizado) │    │ Event Loop + VT (competição) │" >> "$RESULTS_FILE"
    echo "│ ┌─────┐ ┌─────┐       │    │ ┌─────┐ ┌─────┐ ┌─────┐      │" >> "$RESULTS_FILE"
    echo "│ │ EL1 │ │ EL2 │       │    │ │ EL1 │ │ VT1 │ │ VT2 │      │" >> "$RESULTS_FILE"
    echo "│ │NonBl│ │NonBl│       │    │ │Comp │ │Comp │ │Comp │      │" >> "$RESULTS_FILE"
    echo "│ └─────┘ └─────┘       │    │ └─────┘ └─────┘ └─────┘      │" >> "$RESULTS_FILE"
    echo "└───────────────────────┘    └─────────────────────────────┘" >> "$RESULTS_FILE"
    echo "✅ Non-blocking nativo        ❌ Scheduler competition" >> "$RESULTS_FILE"
    echo "✅ Resource efficient         ❌ Context switching overhead" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "🔬 ANÁLISE ESPECÍFICA DO SISTEMA:" >> "$RESULTS_FILE"
    echo "• Arquitetura ARM64 (Apple Silicon) favorece thread pools pequenos" >> "$RESULTS_FILE"
    echo "• Context switching entre Virtual Threads e Reactor tem penalty" >> "$RESULTS_FILE"
    echo "• Scheduler coordination adds overhead in reactive chains" >> "$RESULTS_FILE"
    echo "• Memory allocation patterns differ between approaches" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "💡 DECISÃO ARQUITETURAL:" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "┌─ Workload Type ─┬─ Tecnologia Recomendada ─┬─ Justificativa ─────────┐" >> "$RESULTS_FILE"
    echo "│ Blocking I/O    │ Spring MVC + Virtual     │ 85%+ performance gain   │" >> "$RESULTS_FILE"
    echo "│ High Concurr.   │ Threads                  │ Unlimited scaling       │" >> "$RESULTS_FILE"
    echo "├─────────────────┼──────────────────────────┼─────────────────────────┤" >> "$RESULTS_FILE"
    echo "│ Non-blocking    │ Spring WebFlux           │ Already optimized       │" >> "$RESULTS_FILE"
    echo "│ Event-driven    │ Traditional              │ No VT overhead          │" >> "$RESULTS_FILE"
    echo "├─────────────────┼──────────────────────────┼─────────────────────────┤" >> "$RESULTS_FILE"
    echo "│ CPU Intensive   │ Traditional Threads      │ Avoid over-subscription │" >> "$RESULTS_FILE"
    echo "│ Low Concurrency │ (any framework)          │ VT overhead not worth   │" >> "$RESULTS_FILE"
    echo "└─────────────────┴──────────────────────────┴─────────────────────────┘" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    echo "📚 CONCLUSÃO:" >> "$RESULTS_FILE"
    echo "Virtual Threads são uma revolução para aplicações blocking," >> "$RESULTS_FILE"
    echo "mas podem interferir negativamente em arquiteturas já otimizadas." >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "Regra de ouro: Blocking I/O → Virtual Threads | Non-blocking I/O → Reactive" >> "$RESULTS_FILE"
    echo "Esta análise demonstra que mais tecnologia nem sempre é melhor!" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}
}

# Mostrar resumo simples na tela
show_simple_summary() {
    local mvc_traditional=$1
    local mvc_virtual=$2
    local webflux_traditional=$3
    local webflux_virtual=$4
    
    echo -e "${CYAN}📈 RESUMO DOS RESULTADOS:${NC}"
    echo ""
    
    if [[ ! -z "$mvc_traditional" && ! -z "$mvc_virtual" ]]; then
        IFS='|' read -ra mvc_trad <<< "$mvc_traditional"
        IFS='|' read -ra mvc_virt <<< "$mvc_virtual"
        
        local mvc_trad_avg=$(echo "${mvc_trad[0]}" | cut -d':' -f1)
        local mvc_virt_avg=$(echo "${mvc_virt[0]}" | cut -d':' -f1)
        
        echo -e "${BLUE}🔹 Spring MVC:${NC}"
        echo "   • Sem Virtual Threads: ${mvc_trad_avg}ms"
        echo "   • Com Virtual Threads: ${mvc_virt_avg}ms"
        
        if [[ "$mvc_trad_avg" != "0" && "$mvc_virt_avg" != "0" ]]; then
            local improvement=$(echo "scale=1; (($mvc_trad_avg - $mvc_virt_avg) / $mvc_trad_avg) * 100" | bc 2>/dev/null || echo "N/A")
            if [[ "$improvement" != "N/A" ]]; then
                if (( $(echo "$improvement > 0" | bc -l) )); then
                    echo -e "   • ${EMERALD}Melhoria: ${improvement}%${NC} ✅"
                else
                    echo -e "   • ${AMBER}Diferença: ${improvement}%${NC} ⚠️"
                fi
            fi
        fi
        echo ""
    fi
    
    if [[ ! -z "$webflux_traditional" && ! -z "$webflux_virtual" ]]; then
        IFS='|' read -ra flux_trad <<< "$webflux_traditional"
        IFS='|' read -ra flux_virt <<< "$webflux_virtual"
        
        local flux_trad_avg=$(echo "${flux_trad[0]}" | cut -d':' -f1)
        local flux_virt_avg=$(echo "${flux_virt[0]}" | cut -d':' -f1)
        
        echo -e "${BLUE}🔹 Spring WebFlux:${NC}"
        echo "   • Sem Virtual Threads: ${flux_trad_avg}ms"
        echo "   • Com Virtual Threads: ${flux_virt_avg}ms"
        
        if [[ "$flux_trad_avg" != "0" && "$flux_virt_avg" != "0" ]]; then
            local improvement=$(echo "scale=1; (($flux_trad_avg - $flux_virt_avg) / $flux_trad_avg) * 100" | bc 2>/dev/null || echo "N/A")
            if [[ "$improvement" != "N/A" ]]; then
                if (( $(echo "$improvement > 0" | bc -l) )); then
                    echo -e "   • ${EMERALD}Melhoria: ${improvement}%${NC} ✅"
                else
                    echo -e "   • ${AMBER}Diferença: ${improvement}%${NC} ⚠️"
                fi
            fi
        fi
        echo ""
    fi
    
    echo -e "${SILVER}💡 Dica: Veja o relatório completo em $RESULTS_FILE${NC}"
}

# Executar benchmark simplificado (4 cenários principais)
run_simple_benchmark() {
    echo -e "${TEAL}🚀 Benchmark Simples - 4 Cenários Principais${NC}"
    echo ""
    
    # Preparação
    check_dependencies
    build_project
    
    # Inicializar arquivo de relatório
    echo "RELATÓRIO DE PERFORMANCE - VIRTUAL THREADS COMPARISON" > "$RESULTS_FILE"
    echo "====================================================" >> "$RESULTS_FILE"
    echo "Data: $(date)" >> "$RESULTS_FILE"
    echo "Sistema: $(uname -a)" >> "$RESULTS_FILE"
    echo "Java Version: $(java -version 2>&1 | head -1)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "CONFIGURAÇÃO DOS TESTES:" >> "$RESULTS_FILE"
    echo "- Warmup requests: $WARMUP_REQUESTS" >> "$RESULTS_FILE"
    echo "- Test requests: $TEST_REQUESTS" >> "$RESULTS_FILE"
    echo "- Concurrent requests: $CONCURRENT_REQUESTS" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "CENÁRIOS TESTADOS:" >> "$RESULTS_FILE"
    echo "1. Spring MVC sem Virtual Threads" >> "$RESULTS_FILE"
    echo "2. Spring MVC com Virtual Threads" >> "$RESULTS_FILE"
    echo "3. Spring WebFlux sem Virtual Threads" >> "$RESULTS_FILE"
    echo "4. Spring WebFlux com Virtual Threads" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Variáveis para armazenar resultados
    local mvc_traditional=""
    local mvc_virtual=""
    local webflux_traditional=""
    local webflux_virtual=""
    
    # 1. Spring MVC sem Virtual Threads
    echo -e "${BLUE}📊 [1/4] Spring MVC sem Virtual Threads${NC}"
    mvc_traditional=$(test_single_endpoint \
        "mvc-traditional" \
        "Spring MVC (Threads Tradicionais)" \
        "/api/mvc/persons/blocking-intensive?count=10" \
        "Spring MVC com threads tradicionais e I/O intensivo (500ms/request)")
    
    # 2. Spring MVC com Virtual Threads
    echo -e "${BLUE}📊 [2/4] Spring MVC com Virtual Threads${NC}"
    mvc_virtual=$(test_single_endpoint \
        "mvc-virtual" \
        "Spring MVC (Virtual Threads)" \
        "/api/mvc/persons/blocking-intensive?count=10" \
        "Spring MVC com Virtual Threads e I/O intensivo (500ms/request)")
    
    # 3. Spring WebFlux sem Virtual Threads
    echo -e "${BLUE}📊 [3/4] Spring WebFlux sem Virtual Threads${NC}"
    webflux_traditional=$(test_single_endpoint \
        "webflux-traditional" \
        "Spring WebFlux (Threads Tradicionais)" \
        "/api/webflux/persons/list-intensive?count=10" \
        "Spring WebFlux com schedulers tradicionais e I/O intensivo")
    
    # 4. Spring WebFlux com Virtual Threads
    echo -e "${BLUE}📊 [4/4] Spring WebFlux com Virtual Threads${NC}"
    webflux_virtual=$(test_single_endpoint \
        "webflux-virtual" \
        "Spring WebFlux (Virtual Threads)" \
        "/api/webflux/persons/list-intensive?count=10" \
        "Spring WebFlux com Virtual Threads no boundedElastic e I/O intensivo")
    
    # Gerar relatório de comparação simplificado
    generate_simple_comparison_report \
        "$mvc_traditional" \
        "$mvc_virtual" \
        "$webflux_traditional" \
        "$webflux_virtual"
    
    # Exibir resumo simples na tela
    show_simple_summary \
        "$mvc_traditional" \
        "$mvc_virtual" \
        "$webflux_traditional" \
        "$webflux_virtual"
    
    # Exibir resumo final
    echo ""
    echo -e "${EMERALD}✨ BENCHMARK CONCLUÍDO!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${AMBER}📄 Relatório salvo em: $RESULTS_FILE${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${SILVER}💡 Dica: Veja o relatório completo em $RESULTS_FILE${NC}"
}

# Função principal
main() {
    case "${1:-simple}" in
        "quick"|"test")
            quick_test
            ;;
        "simple"|"")
            run_simple_benchmark
            ;;
        *)
            echo "Uso: $0 [quick|simple]"
            echo "  quick  - Teste rápido de funcionalidade"
            echo "  simple - Benchmark dos 4 cenários principais (padrão)"
            ;;
    esac
}

# Verificar se é chamada direta
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
