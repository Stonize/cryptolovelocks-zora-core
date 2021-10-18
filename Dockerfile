FROM node:14 as base

WORKDIR /app

COPY ./*.json ./

RUN npm install

RUN npm install -g typescript
RUN npm install -g ts-node

COPY ./scripts /app/scripts
COPY ./addresses /app/addresses
COPY ./typechain /app/typechain
