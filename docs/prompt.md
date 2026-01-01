Contexto del Proyecto
Necesito crear un proyecto llamado FeedOps que implemente un sistema de monitoreo automatizado de fuentes de información utilizando n8n y Docker. El sistema debe ser profesional, modular y escalable, diseñado inicialmente para ejecución local pero con arquitectura preparada para despliegue en producción.

Especificaciones Técnicas
1. Arquitectura General
Nombre del proyecto: feedops

Stack principal: n8n + Docker + PostgreSQL

Patrón arquitectónico: Modular con separación clara de responsabilidades

Comunicación: Webhooks para entrada, APIs para procesamiento, Telegram para salida

Persistencia: Base de datos para configuración de usuarios y estado de flujos

2. Requisitos Funcionales
Entradas de Datos:
GitHub: Monitoreo de repositorios específicos por usuario

Eventos: pushes, issues, pull requests, releases

Filtros por organización/repositorio específico

Reddit: Monitoreo de publicaciones en subreddits o usuarios específicos

Filtros por keywords, flairs, puntuación mínima

RSS/Atom: Monitoreo de feeds RSS personalizados

Soporte para múltiples formatos RSS

Detección de actualizaciones periódicas

Procesamiento:
Pipeline de datos: Limpieza, normalización y enriquecimiento

Deduplicación: Evitar notificaciones duplicadas

Priorización: Clasificación por importancia/relevancia

Plantillas personalizables: Formato de mensajes configurable

Salida:
Telegram: Envío a canales/grupos/usuarios específicos

Soporte para formato Markdown

Inline buttons para acciones rápidas

Media embeds cuando esté disponible

Múltiples canales: Posibilidad de enviar a diferentes destinos simultáneamente

3. Características No Funcionales
Escalabilidad: Diseño que permita escalar horizontalmente

Modularidad: Componentes desacoplados para fácil mantenimiento

Configurabilidad: Variables de entorno para toda configuración sensible

Logging: Sistema estructurado de logs para monitoreo

Manejo de errores: Retry logic con exponential backoff

Seguridad: Gestión segura de tokens y credenciales

5. Configuración Docker
Servicios:

n8n: Última versión estable con custom nodes

PostgreSQL: Persistencia de workflows y datos

Redis (opcional): Caché y sesiones

Traefik (para despliegue): Reverse proxy con SSL

Volúmenes: Persistencia de datos y configuración

Redes: Redes aisladas para seguridad

Healthchecks: Verificación de estado de servicios

6. Flujos de Trabajo n8n
Workflow Principal: Orquestación central

Workflows Especializados:

GitHub Listener: Webhook + procesamiento

Reddit Poller: API polling con rate limiting

RSS Fetcher: Periodic fetching y parsing

Telegram Dispatcher: Gestión de envíos y formatos

Workflow de Administración: UI para gestión de suscripciones
8. Escalabilidad Futura
Kubernetes: Preparar manifests para despliegue K8s

Message Queue: Integración con RabbitMQ/Kafka para alto volumen

Microservicios: Separar componentes en servicios independientes

API REST: Exponer endpoints para gestión programática

Dashboard: Interfaz web de administración

9. Documentación Requerida
Guía de instalación local

Guía de configuración de fuentes

Guía de despliegue en producción

API documentation (si aplica)

Troubleshooting guide

10. Criterios de Aceptación
Instalación local funcional con docker-compose up

Configuración de al menos una fuente de cada tipo

Recepción y envío a Telegram funcionando

Sistema de logs operativo

Backup/restore de configuración

Documentación completa

