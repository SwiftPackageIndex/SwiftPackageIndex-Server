docker run --name swiftpackageindex_postgres_dev -e POSTGRES_DB=swiftpackageindex_dev -e POSTGRES_USER=swiftpackageindex -e POSTGRES_PASSWORD=password -p 5432:5432 -d postgres
docker run --name swiftpackageindex_postgres_test -e POSTGRES_DB=swiftpackageindex_test -e POSTGRES_USER=swiftpackageindex -e POSTGRES_PASSWORD=password -p 5433:5432 -d postgres
