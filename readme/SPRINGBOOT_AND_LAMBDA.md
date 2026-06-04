# Guía de uso — Spring Boot + Floci

## 1. Conectar Spring Boot a Floci

El SDK de AWS para Java permite sobreescribir el endpoint por servicio. Cuando `TARGET_ENV=floci`, apuntas todo a `http://localhost:4566` con credenciales fake.

### Dependencias (pom.xml)

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>software.amazon.awssdk</groupId>
      <artifactId>bom</artifactId>
      <version>2.25.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>s3</artifactId>
  </dependency>
  <dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>sqs</artifactId>
  </dependency>
  <dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>lambda</artifactId>
  </dependency>
</dependencies>
```

### application.properties

```properties
# Floci
aws.endpoint=http://localhost:4566
aws.region=us-east-1
aws.accessKey=test
aws.secretKey=test

# Nombres de recursos
aws.s3.bucket=s3-demo-sds-dh-dev
aws.sqs.thumbnailImage=http://sqs.us-east-1.localhost.floci.cloud:4566/000000000000/doodle-dev-generateThumbnailsFromImage
aws.sqs.thumbnailPdf=http://sqs.us-east-1.localhost.floci.cloud:4566/000000000000/doodle-dev-generateThumbnailsFromPdf
```

### Configuración de los clientes AWS (AwsConfig.java)

```java
@Configuration
public class AwsConfig {

    @Value("${aws.endpoint}")
    private String endpoint;

    @Value("${aws.region}")
    private String region;

    @Value("${aws.accessKey}")
    private String accessKey;

    @Value("${aws.secretKey}")
    private String secretKey;

    private AwsCredentialsProvider credentialsProvider() {
        return StaticCredentialsProvider.create(
            AwsBasicCredentials.create(accessKey, secretKey)
        );
    }

    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
            .endpointOverride(URI.create(endpoint))
            .region(Region.of(region))
            .credentialsProvider(credentialsProvider())
            .forcePathStyle(true)   // requerido para LocalStack
            .build();
    }

    @Bean
    public SqsClient sqsClient() {
        return SqsClient.builder()
            .endpointOverride(URI.create(endpoint))
            .region(Region.of(region))
            .credentialsProvider(credentialsProvider())
            .build();
    }

    @Bean
    public LambdaClient lambdaClient() {
        return LambdaClient.builder()
            .endpointOverride(URI.create(endpoint))
            .region(Region.of(region))
            .credentialsProvider(credentialsProvider())
            .build();
    }
}
```

> `forcePathStyle(true)` en S3 es obligatorio para Floci — mismo motivo que el `s3_use_path_style` en Terraform.

### Ejemplo — subir archivo a S3

```java
@Service
public class StorageService {

    private final S3Client s3Client;

    @Value("${aws.s3.bucket}")
    private String bucket;

    public void upload(String key, byte[] content) {
        s3Client.putObject(
            PutObjectRequest.builder().bucket(bucket).key(key).build(),
            RequestBody.fromBytes(content)
        );
    }
}
```

### Ejemplo — enviar mensaje a SQS

```java
@Service
public class QueueService {

    private final SqsClient sqsClient;

    @Value("${aws.sqs.thumbnailImage}")
    private String thumbnailImageQueueUrl;

    public void sendThumbnailJob(String payload) {
        sqsClient.sendMessage(
            SendMessageRequest.builder()
                .queueUrl(thumbnailImageQueueUrl)
                .messageBody(payload)
                .build()
        );
    }
}
```

### Switch Floci ↔ AWS real en Spring Boot

Para no hardcodear el endpoint, usa profiles de Spring:

**application-local.properties**
```properties
aws.endpoint=http://localhost:4566
aws.accessKey=test
aws.secretKey=test
```

**application-aws.properties**
```properties
aws.endpoint=   # vacío — el SDK usa endpoints reales de AWS
aws.accessKey=  # vacío — el SDK toma las credenciales del ambiente (IAM role, env vars, etc.)
aws.secretKey=
```

Y en `AwsConfig.java` condicionas el `endpointOverride`:
```java
private URI getEndpoint() {
    return (endpoint != null && !endpoint.isBlank())
        ? URI.create(endpoint)
        : null;
}

// En cada builder:
S3Client.builder()
    .endpointOverride(getEndpoint())   // null = usa AWS real
    ...
```

Activas el profile con:
```bash
# Local
java -jar app.jar --spring.profiles.active=local

# AWS
java -jar app.jar --spring.profiles.active=aws
```

---

## 2. Actualizar código de las Lambdas Python (A y B)

Las lambdas `generateThumbnailsFromImage-dev` y `generateThumbnailsFromPdf-dev` fueron creadas con un placeholder. Para actualizar el código:

### Paso 1 — Empaquetar el código en un ZIP

```bash
# Desde tu máquina, en la carpeta donde está tu código Python
zip -r function.zip index.py        # Linux/Mac
# o en Windows:
Compress-Archive -Path index.py -DestinationPath function.zip
```

### Paso 2 — Copiar el ZIP al contenedor aws-cli

```bash
docker cp function.zip localstack-aws-aws-cli-1:/tmp/function.zip
```

### Paso 3 — Actualizar la lambda via aws-cli

```bash
# Lambda A
docker-compose run --rm -v ${PWD}/function.zip:/tmp/function.zip aws-cli lambda update-function-code \
  --function-name generateThumbnailsFromImage-dev \
  --zip-file fileb:///tmp/function.zip

# Lambda B
docker-compose run --rm -v ${PWD}/function.zip:/tmp/function.zip aws-cli lambda update-function-code \
  --function-name generateThumbnailsFromPdf-dev \
  --zip-file fileb:///tmp/function.zip
```

### Verificar que se actualizó

```bash
# Invocar la lambda y ver el resultado
docker-compose run --rm aws-cli lambda invoke \
  --function-name generateThumbnailsFromImage-dev \
  --payload '{"test": "ok"}' \
  /tmp/response.json && cat /tmp/response.json
```

### Ver logs de ejecución

```bash
docker-compose run --rm aws-cli logs filter-log-events \
  --log-group-name /aws/lambda/generateThumbnailsFromImage-dev
```

> Terraform no pisará el código que subiste gracias al `lifecycle { ignore_changes = [filename, source_code_hash] }`. Solo si corres `terraform destroy` + `terraform apply` volverá al placeholder.
