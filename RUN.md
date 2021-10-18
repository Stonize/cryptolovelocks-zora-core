# RUN Ethereum Node

docker run -it -p 8545:8545 -p 8546:8546 -p 30303:30303 ethereum/client-go --mainnet --http --http.addr 0.0.0.0 --ws --ws.addr 0.0.0.0 --syncmode light


