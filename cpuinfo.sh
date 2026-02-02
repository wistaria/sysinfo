#!bin/sh

if [ -f /etc/centos-release ]; then
  OS="$(cat /etc/centos-release)"
elif [ -f /etc/os-release ]; then
  OS="$(. /etc/os-release; echo $PRETTY_NAME)"
fi
if [ -f /proc/cpuinfo ]; then
  MODEL=$(grep 'model name' /proc/cpuinfo | tail -1 | cut -d " " -f 3- | sed 's/\s\s*/ /g')
  N_CPUS=$(grep physical.id /proc/cpuinfo | sort -u | wc -l)
  N_PHYS_CORES=$(grep cpu.cores /proc/cpuinfo | sort -u | awk '{print $4}')
  N_LOG_CORES=$(grep processor /proc/cpuinfo | wc -l)
  if [ $(expr ${N_CPUS} '*' ${N_PHYS_CORES}) = ${N_LOG_CORES} ]; then
    HYPER_THREAD=0
  else
    HYPER_THREAD=1
  fi
  BOGOMIPS=$(grep 'bogomips' /proc/cpuinfo | tail -1 | awk '{print $3}')
  MEMORY=$(free -g | awk '/^Mem:/ {print $2}')
  N_GPUS=$(nvidia-smi -L | grep 'GPU' | wc -l)
  MODEL_GPUS=$(nvidia-smi -L | grep GPU | head -1 | awk '{  for (i = 3; i <= NF-2; i++) { printf "%s%s", $i, (i < NF-2 ? OFS : ORS) }}')
  echo "Hostname: $(hostname -s)"
  echo "OS: ${OS}"
  echo "Model: ${MODEL}"
  echo "Total Number of CPUs: ${N_CPUS}"
  echo "Number of Physical Cores per CPU: ${N_PHYS_CORES}"
  echo "Total Number of Logical Cores: ${N_LOG_CORES}"
  echo "Hyper Threading: ${HYPER_THREAD}"
  echo "BogoMIPS: ${BOGOMIPS}"
  echo "Total Memory (GB): ${MEMORY}"
  echo "Number of GPUs: ${N_GPUS}"
  echo "MODEL of GPUs: ${MODEL_GPUS}"
fi
