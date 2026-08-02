#[cfg(test)]
mod tests {
    use starknet::SyscallResultTrait;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
    use starknet::ContractAddress;
    use starkdex::mock_erc20::IMockERC20Dispatcher;
    use starkdex::mock_erc20::IMockERC20DispatcherTrait;
    use starkdex::dex::IDexDispatcher;
    use starkdex::dex::IDexDispatcherTrait;

    const OWNER: felt252 = 0x12345;
    const USER1: felt252 = 0x99999;

   fn deploy_mock_erc20() -> IMockERC20Dispatcher {
    
        let contract = declare("MockERC20").unwrap_syscall().contract_class();
        
        let constructor_args = array![];
        
        let (address, _) = contract.deploy(@constructor_args).unwrap_syscall();
        IMockERC20Dispatcher { contract_address: address }
    }

    fn deploy_dex(token_x: ContractAddress, token_y: ContractAddress) -> IDexDispatcher {
        // find contract by name
        let contract = declare("DEX").unwrap_syscall().contract_class();
        // arguments for constructor
        let mut constructor_args = array![];
        
        token_x.serialize(ref constructor_args);
        token_y.serialize(ref constructor_args);
        let (address, _) = contract.deploy(@constructor_args).unwrap_syscall();
        IDexDispatcher { contract_address: address }
    }

    #[test]
    fn test_get_reserves(){
        let x_token = deploy_mock_erc20();
        let y_token = deploy_mock_erc20();

        let dex = deploy_dex(x_token.contract_address, y_token.contract_address);

        let (reserve_x, reserve_y) = dex.get_reserves();
        assert(reserve_x == 0 && reserve_y ==0, 'should be zero');
    }

    #[test]
    fn test_add_liquidity(){
        let x_token = deploy_mock_erc20();
        let y_token = deploy_mock_erc20();
        let dex = deploy_dex(x_token.contract_address, y_token.contract_address);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        x_token.mint(owner, 500);
        y_token.mint(owner, 500);

        start_cheat_caller_address(x_token.contract_address, owner);
        x_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(x_token.contract_address);

        start_cheat_caller_address(y_token.contract_address, owner);
        y_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(y_token.contract_address);

        start_cheat_caller_address(dex.contract_address, owner);
        dex.add_liquidity(500, 500);
        stop_cheat_caller_address(dex.contract_address);
        
        let (reserve_x, reserve_y) = dex.get_reserves();
        assert(reserve_x == 500 && reserve_y == 500, 'both should be 500');
    }

    #[test]
    fn test_swap_x_to_y(){
        let x_token = deploy_mock_erc20();
        let y_token = deploy_mock_erc20();
        let dex = deploy_dex(x_token.contract_address, y_token.contract_address);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        let user1: ContractAddress = USER1.try_into().unwrap();
        x_token.mint(owner, 1000);
        y_token.mint(owner, 1000);
        x_token.mint(user1, 200);

        start_cheat_caller_address(x_token.contract_address, owner);
        x_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(x_token.contract_address);

        start_cheat_caller_address(y_token.contract_address, owner);
        y_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(y_token.contract_address);

        start_cheat_caller_address(dex.contract_address, owner);
        dex.add_liquidity(500, 500);
        stop_cheat_caller_address(dex.contract_address);

        start_cheat_caller_address(x_token.contract_address, user1);
        x_token.approve(dex.contract_address, 200);
        stop_cheat_caller_address(x_token.contract_address);

        start_cheat_caller_address(dex.contract_address, user1);
        dex.swap_x_to_y(200);
        stop_cheat_caller_address(dex.contract_address);

        let (reserve_x, reserve_y) = dex.get_reserves();
        assert(reserve_x > reserve_y, 'reserve_x must be bigger');
        assert(y_token.balance_of(user1) > 0, 'musnt be zero');


    }

    #[test]
    fn test_swap_y_to_x(){
        let x_token = deploy_mock_erc20();
        let y_token = deploy_mock_erc20();
        let dex = deploy_dex(x_token.contract_address, y_token.contract_address);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        let user1: ContractAddress = USER1.try_into().unwrap();
        x_token.mint(owner, 1000);
        y_token.mint(owner, 1000);
        y_token.mint(user1, 200);

        start_cheat_caller_address(x_token.contract_address, owner);
        x_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(x_token.contract_address);

        start_cheat_caller_address(y_token.contract_address, owner);
        y_token.approve(dex.contract_address, 500);
        stop_cheat_caller_address(y_token.contract_address);

        start_cheat_caller_address(y_token.contract_address, user1);
        y_token.approve(dex.contract_address, 200);
        stop_cheat_caller_address(y_token.contract_address);

        start_cheat_caller_address(dex.contract_address, owner);
        dex.add_liquidity(500, 500);
        stop_cheat_caller_address(dex.contract_address);

        start_cheat_caller_address(dex.contract_address, user1);
        dex.swap_y_to_x(200);
        stop_cheat_caller_address(dex.contract_address);

        let (reserve_x, reserve_y) = dex.get_reserves();
        assert(reserve_y > reserve_x, 'reserve_y must be bigger');
        assert(x_token.balance_of(user1) > 0, 'must be zero');


    }

    #[should_panic(expected: 'Not enough allowance')]
    #[test]
    fn test_swap_insufficient_allowance(){
        let token_x = deploy_mock_erc20();
        let token_y = deploy_mock_erc20();
        let dex = deploy_dex(token_x.contract_address, token_y.contract_address);
        let owner: ContractAddress = OWNER.try_into().unwrap();
        let user1: ContractAddress = USER1.try_into().unwrap();
        token_x.mint(user1, 200);
        token_x.mint(owner, 1000);
        token_y.mint(owner, 1000);

        start_cheat_caller_address(token_x.contract_address, owner);
        token_x.approve(dex.contract_address, 500);
        stop_cheat_caller_address(token_x.contract_address);

        start_cheat_caller_address(token_y.contract_address, owner);
        token_y.approve(dex.contract_address, 500);
        stop_cheat_caller_address(token_y.contract_address);

        start_cheat_caller_address(dex.contract_address, owner);
        dex.add_liquidity(500, 500);
        stop_cheat_caller_address(dex.contract_address);

        start_cheat_caller_address(dex.contract_address, user1);
        dex.swap_x_to_y(200);


    }

}