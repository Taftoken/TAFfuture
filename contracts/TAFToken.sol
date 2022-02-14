// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interface/IUniswapV2Router02.sol";
import "./interface/IUniswapV2Factory.sol";


contract TAFToken is ERC20PresetMinterPauser, Ownable{

    using SafeMath for uint256;
    using Address for address;

    uint256 public liquidityFee;
    uint256 public maxTxAmount; // 0.1% of Total Supply
    uint256 private numTokensSellToAddToLiquidity; // 0.025% of Total Supply

    bool public isLiquidityFeeEnabled;
    bool inSwapAndLiquify;
    mapping(address => bool) public _isExcluded;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }


    bytes32 public DOMAIN_SEPARATOR; 

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");


    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    
    // the percentage of PTM which can be created per mint
    //uint256 _mintCap = 2; // 2% of current totalSupply
    
    string _version = "1";

    mapping(address => uint) public nonces;

    /// @notice A record of each accounts delegate
    mapping (address => address) public delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;
    

    constructor() ERC20PresetMinterPauser("TAFToken", "TAF"){
        mint(msg.sender, 100000000 * 10**18);

        isLiquidityFeeEnabled = true;
        maxTxAmount = totalSupply().div(1000);
        numTokensSellToAddToLiquidity = totalSupply().div(4000);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // mainnet 0x10ED43C718714eb63d5aA57B78B54704E256024E
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        excludeForFee(address(this));
        // excludeForFee(msg.sender);

        setLiquidityFee(500);
    }

    function init() public payable{
        mint(address(this), 100000 * 10**18);
        _approve(address(this), address(uniswapV2Router), 1000000 * 10**18);
        addLiquidity(1000 * 10**18,  msg.value);
        // swapTokensForEth(10 * 10**18);
    }

    /**
    Just to handle and recive Ethers if needed
     */
    receive() external payable {}

    /**
    set Liquidity fee
    1 = 0.01%
     */
    function setLiquidityFee(uint256 _fee) public onlyOwner{
        liquidityFee = _fee;
    }

    /**
    Add or remove address to charge fee
     */
   function excludeForFee(address account) public onlyOwner{
        _isExcluded[account] = true;
    }

   function includeForFee(address account) public onlyOwner{
        _isExcluded[account] = false;
    }

    /**
    Switch liquidity fee on / off
     */
    function toggleLiquidityFee() public onlyOwner{
        isLiquidityFeeEnabled = !isLiquidityFeeEnabled;
    }


    function _transfer(
        address from,
        address to,
        uint256 amount
    )  internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // if(from != owner() && to != owner())
        //     require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        uint256 fee = 0;

        if (isLiquidityFeeEnabled && !_isExcluded[from] && !_isExcluded[to] && from != address(uniswapV2Pair) && liquidityFee > 0) {
            fee = (liquidityFee * amount) / 10000;

            if(fee > 0){
                super._transfer(from, address(this), fee);
                swapAndLiquify(fee);
            }
        }
        
        
        //transfer rest amount to user
        super._transfer(from, to, amount - fee);
    }


    function swapAndLiquify(uint256 contractTokenBalance) private {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
       addLiquidity(otherHalf, newBalance);

        // emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount * 10);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount * 10);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }
}