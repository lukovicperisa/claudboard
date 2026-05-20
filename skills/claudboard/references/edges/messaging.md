# Messaging Edge Detection

Detection entries for asynchronous messaging transports: message brokers, event streams, queues. Each entry provides grep commands, extraction rules, and example edge output.

**Applies to:** workspace mode (multi-repo) edge extraction.

---

## Entry template

| Field | Description |
|-------|-------------|
| **Grep** | Command(s) to detect the transport |
| **Extract** | What to pull from matches |
| **Direction** | `inbound` (consumer/subscriber) or `outbound` (producer/publisher) |
| **Edge example** | YAML shape emitted in the report |

---

## Java/Spring

### Kafka Producer (Java/Kotlin)

```bash
grep -rn 'KafkaTemplate' --include='*.java' --include='*.kt' src/
grep -rn '\.send(' --include='*.java' --include='*.kt' src/
grep -rn '@SendTo' --include='*.java' --include='*.kt' src/
```

- For `KafkaTemplate.send("topic-name", ...)` → extract topic literal as target
- For `@SendTo("topic-name")` → extract topic value as target
- If topic is a constant reference → grep for the constant definition to resolve the string value; if unresolvable → target = `unknown`
- Direction: outbound

**Edge example:**
```yaml
- {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "order-created", schema_ref: null}
```

### Kafka Consumer (Java/Kotlin)

```bash
grep -rn '@KafkaListener' --include='*.java' --include='*.kt' src/
```

- Extract `topics = {"..."}` value as target
- If topics is a constant array, grep for the constant definition; if unresolvable → target = `unknown`
- Direction: inbound

**Edge example:**
```yaml
- {family: messaging, protocol: kafka, type: kafka, direction: inbound, target: "order-created", schema_ref: null}
```

### Spring AMQP — RabbitMQ (Java/Kotlin)

```bash
grep -rn '@RabbitListener' --include='*.java' --include='*.kt' src/
grep -rn 'RabbitTemplate' --include='*.java' --include='*.kt' src/
```

**Inbound:** `@RabbitListener(queues = "...")` → extract queue name as target.

**Outbound:** `RabbitTemplate.convertAndSend(exchange, routingKey, ...)` → extract exchange and routingKey; format as `"<exchange>/<routingKey>"` if both are literals, otherwise extract what is resolvable.

**Edge examples:**
```yaml
- {family: messaging, protocol: rabbitmq, type: rabbitmq, direction: inbound, target: "order.queue", schema_ref: null}
- {family: messaging, protocol: rabbitmq, type: rabbitmq, direction: outbound, target: "order.exchange/order.created", schema_ref: null}
```

### Spring JMS (Java/Kotlin)

```bash
grep -rn '@JmsListener' --include='*.java' --include='*.kt' src/
grep -rn 'JmsTemplate' --include='*.java' --include='*.kt' src/
```

**Inbound:** `@JmsListener(destination = "...")` → extract destination name as target.

**Outbound:** `JmsTemplate.send(destination, ...)` or `JmsTemplate.convertAndSend(destination, ...)` → extract destination literal as target.

**Edge examples:**
```yaml
- {family: messaging, protocol: jms, type: jms, direction: inbound, target: "order.queue", schema_ref: null}
- {family: messaging, protocol: jms, type: jms, direction: outbound, target: "notification.queue", schema_ref: null}
```

### AWS SDK v1/v2 — SNS / SQS (Java/Kotlin)

```bash
grep -rn 'SnsClient\|AmazonSNS' --include='*.java' --include='*.kt' src/
grep -rn 'SqsClient\|AmazonSQS' --include='*.java' --include='*.kt' src/
```

**SNS outbound:** `SnsClient.publish(PublishRequest.builder().topicArn("...").build())` → extract `topicArn` as target.

**SQS outbound:** `SqsClient.sendMessage(SendMessageRequest.builder().queueUrl("...").build())` → extract `queueUrl` as target.

**SQS inbound:** `SqsClient.receiveMessage(ReceiveMessageRequest.builder().queueUrl("...").build())` → extract `queueUrl` as target.

**Edge examples:**
```yaml
- {family: messaging, protocol: sns, type: sns, direction: outbound, target: "arn:aws:sns:us-east-1:123456789:order-events", schema_ref: null}
- {family: messaging, protocol: sqs, type: sqs, direction: outbound, target: "https://sqs.us-east-1.amazonaws.com/123456789/order-queue", schema_ref: null}
```

### Azure Service Bus (Java/Kotlin)

```bash
grep -rn 'ServiceBusSenderClient\|ServiceBusProcessorClient\|ServiceBusReceiverClient' \
  --include='*.java' --include='*.kt' src/
```

- `ServiceBusSenderClient.sendMessage(...)` → look for the queue/topic name in the client builder chain (`new ServiceBusClientBuilder().sender().queueName("...")`); extract as target
- `ServiceBusProcessorClient` or `ServiceBusReceiverClient` → extract `queueName`/`topicName` from builder; direction: inbound
- Direction: outbound for sender, inbound for receiver/processor

**Edge example:**
```yaml
- {family: messaging, protocol: azure-service-bus, type: azure-service-bus, direction: outbound, target: "order-topic", schema_ref: null}
```

### Google Pub/Sub (Java/Kotlin)

```bash
grep -rn 'Publisher\.newBuilder\|TopicName\.of(' --include='*.java' --include='*.kt' src/
grep -rn 'Subscriber\.newBuilder\|SubscriptionName\.of(' --include='*.java' --include='*.kt' src/
```

- `Publisher.newBuilder(TopicName.of(projectId, topicId))` → extract `topicId` string literal as target; direction: outbound
- `Subscriber.newBuilder(SubscriptionName.of(projectId, subscriptionId), ...)` → extract `subscriptionId`; direction: inbound

**Edge example:**
```yaml
- {family: messaging, protocol: google-pubsub, type: google-pubsub, direction: outbound, target: "order-events", schema_ref: null}
```

### Solace Spring Cloud Stream (Java/Kotlin)

**Outbound (config-based):**

| File | Pattern | What to Extract |
|------|---------|-----------------|
| `application.yml` | `spring.cloud.stream.bindings.{channel}.destination` | Destination value for each `@Output` channel |
| Java code | `@Output("channelName")` or `StreamBridge` | Link config destination to producer channel |

**Extraction example (application.yml):**
```yaml
spring:
  cloud:
    stream:
      bindings:
        orderOut:
          destination: order/created
```
→ Record outbound edge with target `"order/created"`

**Inbound (annotation-based):**

```bash
grep -rn '@StreamListener' --include='*.java' --include='*.kt' src/
```

- Extract binding name from `@StreamListener("orderIn")`
- Look up `spring.cloud.stream.bindings.orderIn.destination` in config → use that value as target
- Direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: solace-scs, type: solace-scs, direction: outbound, target: "order/created", schema_ref: null}
- {family: messaging, protocol: solace-scs, type: solace-scs, direction: inbound, target: "order/created", schema_ref: null}
```

### Solace JCSMP (Java/Kotlin)

**Outbound:**

```bash
grep -rn 'Topic\.of(\|Queue\.get(' --include='*.java' --include='*.kt' src/
```

- `Topic.of("...")` → extract literal topic name as target; direction: outbound
- `Queue.get("...")` → extract literal queue name as target; direction: outbound
- If topic is a constant: grep for the constant definition to resolve the string value; if unresolvable → `<unresolved: CONSTANT_NAME>`

**Inbound:**

```bash
grep -rn 'addSubscription' --include='*.java' --include='*.kt' src/
```

- `consumer.addSubscription(Topic.of("..."))` → extract topic literal as target; direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: solace-jcsmp, type: solace-jcsmp, direction: outbound, target: "order/created", schema_ref: null}
- {family: messaging, protocol: solace-jcsmp, type: solace-jcsmp, direction: inbound, target: "order/created", schema_ref: null}
```

---

## TypeScript / JavaScript / Node.js

### kafkajs (TypeScript/Node.js)

```bash
grep -rn 'producer\.send({' --include='*.ts' --include='*.js' src/
grep -rn 'consumer\.subscribe({' --include='*.ts' --include='*.js' src/
```

- `producer.send({ topic: "..." })` → extract `topic` literal as target; direction: outbound
- `consumer.subscribe({ topic: "..." })` or `consumer.subscribe({ topics: [...] })` → extract topic name(s); direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: kafka, type: kafka, direction: outbound, target: "order-created", schema_ref: null}
- {family: messaging, protocol: kafka, type: kafka, direction: inbound, target: "order-created", schema_ref: null}
```

### amqplib — RabbitMQ (TypeScript/Node.js)

```bash
grep -rn 'channel\.publish\|channel\.sendToQueue\|channel\.consume' \
  --include='*.ts' --include='*.js' src/
```

- `channel.publish(exchange, routingKey, ...)` → extract `exchange` and `routingKey` literals; format target as `"<exchange>/<routingKey>"`; direction: outbound
- `channel.sendToQueue(queue, ...)` → extract `queue` literal; direction: outbound
- `channel.consume(queue, ...)` → extract `queue` literal; direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: rabbitmq, type: rabbitmq, direction: outbound, target: "orders.exchange/order.created", schema_ref: null}
- {family: messaging, protocol: rabbitmq, type: rabbitmq, direction: inbound, target: "order.queue", schema_ref: null}
```

### mqtt.js (TypeScript/Node.js)

```bash
grep -rn 'mqtt\.connect\|client\.publish\|client\.subscribe' \
  --include='*.ts' --include='*.js' src/
```

- `mqtt.connect(url)` → record broker URL; used as context for the publish/subscribe calls that follow
- `client.publish(topic, ...)` → extract `topic` literal; direction: outbound
- `client.subscribe(topic, ...)` → extract `topic` literal; direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: mqtt, type: mqtt, direction: outbound, target: "sensors/temperature", schema_ref: null}
- {family: messaging, protocol: mqtt, type: mqtt, direction: inbound, target: "sensors/+/reading", schema_ref: null}
```

### Redis pub/sub — ioredis / redis (TypeScript/Node.js)

```bash
grep -rn 'publisher\.publish\|subscriber\.subscribe\|client\.publish\|client\.subscribe' \
  --include='*.ts' --include='*.js' src/
```

- `publisher.publish(channel, ...)` → extract `channel` literal; direction: outbound
- `subscriber.subscribe(channel, ...)` → extract `channel` literal; direction: inbound
- Only flag when the client is named `publisher`/`subscriber` or the calling context makes the pub/sub intent clear

**Edge examples:**
```yaml
- {family: messaging, protocol: redis-pubsub, type: redis-pubsub, direction: outbound, target: "notifications:user", schema_ref: null}
- {family: messaging, protocol: redis-pubsub, type: redis-pubsub, direction: inbound, target: "notifications:user", schema_ref: null}
```

### AWS SDK v3 — SNS / SQS (TypeScript/Node.js)

```bash
grep -rn 'SNSClient\|SQSClient' --include='*.ts' --include='*.js' src/
grep -rn 'PublishCommand\|SendMessageCommand\|ReceiveMessageCommand' \
  --include='*.ts' --include='*.js' src/
```

- `SNSClient.send(new PublishCommand({ TopicArn: "..." }))` → extract `TopicArn` as target; direction: outbound
- `SQSClient.send(new SendMessageCommand({ QueueUrl: "..." }))` → extract `QueueUrl` as target; direction: outbound
- `SQSClient.send(new ReceiveMessageCommand({ QueueUrl: "..." }))` → extract `QueueUrl` as target; direction: inbound

**Edge examples:**
```yaml
- {family: messaging, protocol: sns, type: sns, direction: outbound, target: "arn:aws:sns:us-east-1:123:order-events", schema_ref: null}
- {family: messaging, protocol: sqs, type: sqs, direction: inbound, target: "https://sqs.us-east-1.amazonaws.com/123/order-queue", schema_ref: null}
```

### @nestjs/microservices (TypeScript)

```bash
grep -rn 'ClientProxy\|@MessagePattern\|@EventPattern' --include='*.ts' src/
```

- `ClientProxy.emit(pattern, data)` → extract `pattern` string literal; direction: outbound
- `ClientProxy.send(pattern, data)` → extract `pattern` string literal; direction: outbound (request-response)
- `@MessagePattern(pattern)` → extract `pattern` literal; direction: inbound (request-response)
- `@EventPattern(pattern)` → extract `pattern` literal; direction: inbound (event)

**Edge examples:**
```yaml
- {family: messaging, protocol: nestjs-microservice, type: nestjs-microservice, direction: outbound, target: "order_created", schema_ref: null}
- {family: messaging, protocol: nestjs-microservice, type: nestjs-microservice, direction: inbound, target: "get_order", schema_ref: null}
```
