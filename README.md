# ens-auth-solidity

Smart contract validation for ENS Subdomain Authentication (EIP-5131)

(Test run suggests 82,341 gas to do the check)

Discussion here:
https://ethereum-magicians.org/t/eip-5131-ens-authentication-link/9458

## Setup

Using truffle framework

npm install -g truffle

npm install -g ganache-cli

### install dependencies

npm install

### Compile

truffle compile

### Start development server

ganache-cli --accounts=1000 -l 20000000

### Deploy migrations

truffle migrate

### Run tests

truffle test
