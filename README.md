# Buckets

> "Never half-ass two things. Whole-ass one thing."
> 
> — <cite>Ron Swanson<cite>

`Buckets` is a set of smart contracts for easily and efficiently fractionalizing _**any ERC721 NFT**_ into ERC20 tokens. There are no fees, no middlemen, and no trust involved. The contracts are unowned and the code is immutable.

## BucketFactory
The `BucketFactory` allows users to deposit ERC721 NFTs and mint corresponding ERC20 tokens. If an ERC20 token does not yet exist for the ERC721 contract, the `BucketFactory` will deploy a new lightweight clone `ERC20Bucket` contract. 

Every deposited NFT mints 10,000 of the corresponding `ERC20Bucket` tokens to the minter or specified recipient. Why 10,000? Think basis points 

Anyone with a balance greater than 10,000 of an `ERC20Bucket` token can call `redeem` to burn their tokens and receive specific ERC721 NFT(s).

## ERC20Bucket
An `ERC20Bucket` is an ERC20 token that represents a fraction of an NFT. Only the `BucketFactory` can mint new tokens or burn existing tokens.

# Caveats

- Nonstandard ERC721 contracts, especially those that do not have true immutable ownership or intentionally break composability of the ERC721 standard may be incompatible with `Buckets`.
- `ERC20Bucket` `name`s and `symbol`s will break if someone tries to get cheeky and deploy a contract with a name or symbol longer than ~65,500 bytes. Consider it a feature, not a bug.