provider "aws" {
  region = "eu-north-1"
}

# --- TASK 1: Створення та налаштування сховища ---

# Генеруємо унікальний ID для бакета
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "storage" {
  bucket = "vlad-storage-lab7-${random_id.suffix.hex}"
  
  # Task 2: Вмикаємо Object Lock (аналог Immutable storage / WORM в Azure)
  object_lock_enabled = true
}

# Налаштування версіонування (Data Protection)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Життєвий цикл: Переміщення в Cool storage через 30 днів
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "Movetocool"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER_IR" 
    }
  }
}

# --- TASK 2: Secure Storage (Private Access & Object Lock) ---

# Блокуємо весь публічний доступ (Disable public access)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Налаштування політики утримання (Time-based retention на 180 днів)
resource "aws_s3_bucket_object_lock_configuration" "lock" {
  bucket = aws_s3_bucket.storage.id

  rule {
    default_retention {
      mode = "COMPLIANCE" # Жорсткий режим: ніхто не видалить файл, навіть root
      days = 180
    }
  }
}

# Об'єкт у папці securitytest
resource "aws_s3_object" "sample_file" {
  bucket = aws_s3_bucket.storage.id
  key    = "securitytest/sample.txt"
  content = "Hello from Lab 7 - Secure AWS Storage"
  
  # Файл успадкує 180 днів блокування
}

# --- TASK 3: Обмеження мережевого доступу ---

resource "aws_vpc" "vnet1" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vnet1" }
}

# Створюємо VPC Endpoint для S3 (Gateway тип)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vnet1.id
  service_name = "com.amazonaws.eu-north-1.s3"
  
  tags = { Name = "s3-service-endpoint" }
}

# Створюємо таблицю маршрутизації, щоб VPC Endpoint працював
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vnet1.id
  tags   = { Name = "private-rt" }
}

# Прив'язуємо Endpoint до таблиці маршрутів
resource "aws_vpc_endpoint_route_table_association" "s3_assoc" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}