#!/bin/bash

# Script mejorado para generar múltiples pares de claves SSH con email sin entrada del usuario

# Configuramos opciones de salida seguras para el script
set -e
set -o errexit
set -o nounset
set -o pipefail

# Determinar el directorio home del usuario real, incluso cuando se ejecuta con sudo
if [[ ! -z "${SUDO_USER}" ]]; then
  USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
  USER_HOME=$HOME
fi

# Definición de variables para personalización
SSH_DIR="${USER_HOME}/.ssh/clusterkey"  # Directorio para almacenar las claves SSH
SSH_KEY_NAME="id_rsa_clusterkey"        # Nombre predeterminado del par de claves SSH
SSH_EMAIL="user@example.com"            # Email para asociar con la clave SSH
LOG_FILE="${USER_HOME}/ssh_keygen.log"  # Archivo de log

# Definir la ruta completa al archivo de la clave privada
SSH_PRIVATE_KEY="${SSH_DIR}/${SSH_KEY_NAME}"

# Crear directorio para logs si no existe
if [ ! -d "$(dirname "$LOG_FILE")" ]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  chmod 755 "$(dirname "$LOG_FILE")"
fi

# Función para crear el directorio SSH si no existe
create_ssh_dir() {
    mkdir -p "$SSH_DIR" || handle_error "Creación del directorio SSH"
    chmod 700 "$SSH_DIR" || handle_error "Ajuste de permisos del directorio SSH"
}

# Función para generar un nuevo par de claves SSH
generate_ssh_keys() {
    if [ ! -f "$SSH_PRIVATE_KEY" ]; then
        echo "Generando un nuevo par de claves SSH..."
        ssh-keygen -t rsa -b 2048 -N "" -C "$SSH_EMAIL" -f "$SSH_PRIVATE_KEY" || handle_error "Generación de claves SSH"
        echo "Par de claves SSH generado correctamente en $SSH_DIR."
    else
        echo "Ya existe un par de claves SSH en $SSH_DIR."
    fi
}

# Función para manejar errores
handle_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: $1." >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: $1." >> "$LOG_FILE"
    exit 1
}

# Ajuste de los permisos de las claves
adjust_key_permissions() {
    chmod 600 "$SSH_PRIVATE_KEY" || handle_error "Ajuste de permisos de la clave privada"
    chmod 644 "${SSH_PRIVATE_KEY}.pub" || handle_error "Ajuste de permisos de la clave pública"
}

# Ejecución de las funciones principales
create_ssh_dir
generate_ssh_keys
adjust_key_permissions

echo "Gestión de claves SSH completada correctamente."