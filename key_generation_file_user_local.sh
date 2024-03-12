#!/bin/bash

# Script mejorado para gestionar claves SSH con personalización

# Configuramos opciones de salida para el script
set -e
set -o errexit  # Finaliza el script si un comando falla
set -o nounset  # Finaliza el script si se usa una variable no declarada

# Personaliza aquí el nombre de la clave y el directorio si es necesario
SSH_DIR="${HOME}/.ssh" # Modificado para usar el directorio .ssh del usuario actual
SSH_KEY_NAME="id_rsa_custom" # Nombre personalizado para las claves SSH
SSH_PRIVATE_KEY="${SSH_DIR}/${SSH_KEY_NAME}"
LOG_FILE="/var/log/ssh_keygen.log" # Uso de mayúsculas para nombres de variables constantes

# Función para manejar errores
handle_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: $1 falló" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: $1 falló" >> "$LOG_FILE"
    dmesg >> "$LOG_FILE"
    exit 1
}

# Crea el directorio para las claves SSH si no existe
create_ssh_dir() {
    mkdir -p "$SSH_DIR" 2>>"$LOG_FILE" || handle_error "Creación del directorio SSH"
    chmod 700 "$SSH_DIR" 2>>"$LOG_FILE" || handle_error "Ajuste de permisos del directorio SSH"
}

# Genera un nuevo par de claves SSH si no existe
generate_ssh_keys() {
    if [ ! -f "$SSH_PRIVATE_KEY" ]; then
        echo "Generando un nuevo par de claves SSH..."
        ssh-keygen -t rsa -b 2048 -N "" -f "$SSH_PRIVATE_KEY" 2>>"$LOG_FILE" || handle_error "Generación de claves SSH"
        echo "Par de claves SSH generado correctamente en $SSH_DIR."
    else
        echo "Ya existe un par de claves SSH en $SSH_DIR."
    fi
}

# Ajusta los permisos de las claves
adjust_key_permissions() {
    chmod 600 "$SSH_PRIVATE_KEY" 2>>"$LOG_FILE" || handle_error "Ajuste de permisos de la clave privada"
    chmod 644 "${SSH_PRIVATE_KEY}.pub" 2>>"$LOG_FILE" || handle_error "Ajuste de permisos de la clave pública"
}

# Función principal
main() {
    echo "Inicio de la gestión de claves SSH..." | tee -a "$LOG_FILE"
    create_ssh_dir
    generate_ssh_keys
    adjust_key_permissions
    echo "Gestión de claves SSH completada correctamente." | tee -a "$LOG_FILE"
}

# Ejecutamos la función principal
main

# Finalizamos el script
exit 0