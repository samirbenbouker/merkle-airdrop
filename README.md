create input.json file
== Command ==
forge script script/GenerateInput.s.sol:GenerateInput

create ouput.json file
== Command ==
forge script script/MakeMerkle.s.sol:MakeMerkle




step1 run makefile for deploy the contracts
== Command ==
make deploy
== Return ==
0: contract MerkleAirdrop 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
1: contract BagelToken 0x5FbDB2315678afecb367f032d93F642f64180aa3

step2 create a digest using getMessageHash function into MerkleAirdop contract (for this case using anvil rpc)
== Command ==
cast call <contract address> <function name & parameters> <values> --rpc-url <rpc url>
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "getMessageHash(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 25000000000000000000 --rpc-url http://localhosst:8545
== Return ==
messageHash = 0x184e30c4b19f5e304a89352421dc50346dad61c461e79155b910e73fd856dc72

step3 create a sign using digest and private key (in this case using private key from anvil)
== Command ==
(we use --no-hash because we dont want hash again the message)
cast wallet sign --no-hash <digest message> --private-key <wallet private key>
cast wallet sign --no-hash 0x184e30c4b19f5e304a89352421dc50346dad61c461e79155b910e73fd856dc72 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
== Return ==
signature = 0xfbd2270e6f23fb5fe9248480c0f4be8a4e9bd77c3ad0b1333cc60b5debc511602a2a06c24085d8d7c038bad84edc53664c8ce0346caeaa3570afec0e61144dc11c




run interact script
forge script script/Interact.s.sol:ClaimAirdrop --rpc-url <rpc url> --private-key <private key who will pay gas> --broadcast
forge script script/Interact.s.sol:ClaimAirdrop --rpc-url http://localhost:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --broadcast

check if user have claim his own airdrop
== Command ==
cast call <address contract> "balanceOf(address)" <user wallet>
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

== Return ==
0x0000000000000000000000000000000000000000000000015af1d78b58c40000

and convert this data to decimals
== Command ==
cast --to-dec <data>
cast --to-dec 0x0000000000000000000000000000000000000000000000015af1d78b58c40000

== Return ==
25000000000000000000 




deploy and run zksync sh
== Command ==
chmod +x interactZk.sh && ./interactZk.sh