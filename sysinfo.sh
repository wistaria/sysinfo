#!/bin/sh

FLAG_TABLE=0
while getopts "t" opt; do
  case "$opt" in
    t) FLAG_TABLE=1 ;;
    \?) exit 1 ;;
  esac
done

HOSTNAME="unknown"
if command -v hostname >/dev/null 2>&1; then
  HOSTNAME="$(hostname 2>/dev/null | awk -F. '{print $1}')"
fi

OS="Unknown"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  OS="$(. /etc/os-release; echo "$PRETTY_NAME")"
elif [ -f /etc/centos-release ]; then
  OS="$(cat /etc/centos-release)"
elif [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
  if command -v sw_vers >/dev/null 2>&1; then
    OS="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  else
    OS="macOS (Darwin)"
  fi
fi

MODEL="Unknown"
N_CPUS=0
N_PHYS_CORES=0
N_LOG_CORES=0
HYPER_THREAD=0
BOGOMIPS=0
if [ -f /proc/cpuinfo ]; then
  MODEL=$(grep 'model name' /proc/cpuinfo | tail -1 | cut -d " " -f 3- | sed 's/\s\s*/ /g')
  N_CPUS=$(grep physical.id /proc/cpuinfo | sort -u | wc -l)
  N_PHYS_CORES=$(grep cpu.cores /proc/cpuinfo | sort -u | awk '{print $4}')
  N_LOG_CORES=$(grep -c processor /proc/cpuinfo)
  if [ $((${N_CPUS} * ${N_PHYS_CORES})) -eq "${N_LOG_CORES}" ]; then
    HYPER_THREAD=0
  else
    HYPER_THREAD=1
  fi
  BOGOMIPS=$(grep 'bogomips' /proc/cpuinfo | tail -1 | awk '{print $3}')
elif command -v sysctl >/dev/null 2>&1; then
  MODEL="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo Unknown)"
  N_CPUS="$(sysctl -n hw.packages 2>/dev/null || echo 1)"
  N_PHYS_TOTAL="$(sysctl -n hw.physicalcpu 2>/dev/null || echo 0)"
  N_LOG_CORES="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 0)"
  if [ "$N_CPUS" -gt 0 ] && [ "$N_PHYS_TOTAL" -gt 0 ]; then
    N_PHYS_CORES=$((N_PHYS_TOTAL / N_CPUS))
    [ "$N_PHYS_CORES" -eq 0 ] && N_PHYS_CORES="$N_PHYS_TOTAL"
  else
    N_PHYS_CORES=0
  fi
  if [ "$N_PHYS_TOTAL" -gt 0 ] && [ "$N_LOG_CORES" -gt 0 ] && [ "$N_LOG_CORES" -gt "$N_PHYS_TOTAL" ]; then
    HYPER_THREAD=1
  else
    HYPER_THREAD=0
  fi
fi

MEMORY=0
if [ -f /proc/meminfo ]; then
  MEMORY_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  MEMORY=$((MEMORY_KB / 1024 / 1024))
elif command -v sysctl >/dev/null 2>&1; then
  MEMORY_B="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  MEMORY=$((MEMORY_B / 1024 / 1024 / 1024))
fi

N_GPUS=0
MODEL_GPUS=""
if command -v nvidia-smi >/dev/null 2>&1; then
  MODEL_GPUS=$(nvidia-smi -L | grep GPU | head -1 | awk '{  for (i = 3; i <= NF-2; i++) { printf "%s%s", $i, (i < NF-2 ? OFS : ORS) }}')
  N_GPUS=$(nvidia-smi -L | grep -c 'GPU')
elif [ "$(uname -s 2>/dev/null)" = "Darwin" ] && command -v system_profiler >/dev/null 2>&1; then
  MODEL_GPUS="$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model:/ {print $2; exit}')"
  N_GPUS="$(system_profiler SPDisplaysDataType | awk -F': ' '/Total Number of Cores/ {print $2}')"
fi

if [ $FLAG_TABLE -eq 1 ]; then
  printf "| %s | %s | %s | %d | %d | %d | %d | %s | %d | %d | %s |\n" "${HOSTNAME}" "${OS}" "${MODEL}" "${N_CPUS}" "${N_PHYS_CORES}" "${N_LOG_CORES}" "${HYPER_THREAD}" "${BOGOMIPS}" "${MEMORY}" "${MODEL_GPUS}" "${N_GPUS}" 
else
  printf "%-32s : %s\n" "Hostname" "${HOSTNAME}"
  printf "%-32s : %s\n" "OS" "${OS}"
  printf "%-32s : %s\n" "Model" "${MODEL}"
  printf "%-32s : %d\n" "Total Number of CPU(s)" "${N_CPUS}"
  printf "%-32s : %d\n" "Number of Physical Cores per CPU" "${N_PHYS_CORES}"
  printf "%-32s : %d\n" "Total Number of Logical Cores" "${N_LOG_CORES}"
  printf "%-32s : %d\n" "Hyper Threading" "${HYPER_THREAD}"
  printf "%-32s : %s\n" "BogoMIPS" "${BOGOMIPS}"
  printf "%-32s : %d\n" "Total Memory (GB)" "${MEMORY}"
  printf "%-32s : %s\n" "MODEL of GPU(s)" "${MODEL_GPUS}"
  printf "%-32s : %d\n" "Number of GPU(s)" "${N_GPUS}"
fi
