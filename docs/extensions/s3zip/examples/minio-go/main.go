package main

import (
	"context"
	"io"
	"log"
	"os"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

func main() {
	s3Client, err := uitstor.New("uitstor-server-address:9000", &uitstor.Options{
		Creds: credentials.NewStaticV4("access-key", "secret-key", ""),
	})
	if err != nil {
		log.Fatalln(err)
	}

	var opts uitstor.GetObjectOptions

	// Add extract header to request:
	opts.Set("x-uitstor-extract", "true")

	// Download API.md from the archive
	rd, err := s3Client.GetObject(context.Background(), "your-bucket", "path/to/file.zip/data.csv", opts)
	if err != nil {
		log.Fatalln(err)
	}
	_, err = io.Copy(os.Stdout, rd)
	if err != nil {
		log.Fatalln(err)
	}
}
