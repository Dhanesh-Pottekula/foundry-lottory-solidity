### deploy ###

forge -> compile and interacte with contract 
cast -> interact with deployed contracts
anvil -> deploy a local blockchain
forge fmt --> to format the solidity code

forge create <contract > --rpc-url <url > --pricate-key <private key>
 
forge script <contract path> --rpc-url <url> --account <key name> --sender <wallet address> --broadcast -vvvv {key name-> get when casted, wallet address -> public address in wallet, script --> runs the specified script }

### casting the private key ###
cast wallet import defaultkey --interactive   {cast your  private key once so every time it will be used as default}
cast wallet list { gives all keys u stored}

cast --to-base <hex> dec { converts hex into decimal values }

### interacting with deployed contract ###
forge inspect <contract name> abi {gives the abi}

cast send <contract address> "<function name(types of args)>" <args> --rpc-url <url > --pricate-key <private key>
cast call <contract address> "<function name(types of args)>" <args> --rpc-url <url > --pricate-key <private key>  { call for view functions }


### test ###

forge test --mt <testname> -vvvv 
forge test --fork-url <chain url >

### storage ###
cast storage <contract address> <storage slot> { can access the storage};
