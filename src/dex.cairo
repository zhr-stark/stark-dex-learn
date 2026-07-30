
use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess,
StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,};
use starknet::{ContractAddress, get_caller_address, get_contract_address};

#[starknet::interface]
trait IDex<TState>{
    fn add_liquidity(ref self: TState, x: u256, y: u256);
    fn get_reserves(self: @TState) -> (u256, u256);
    fn swap_x_to_y(ref self: TState, amount_in: u256);
    fn swap_y_to_x(ref self: TState, amount_in: u256);
 }

 #[starknet::interface]
trait IERC20<TState> {
    fn transfer_from(ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;

}
 #[starknet::contract]
 mod DEX {
    use super::{ContractAddress, get_caller_address, get_contract_address};
    use super::IERC20Dispatcher;
    use super::IERC20DispatcherTrait;
    use super::{Map, StoragePointerReadAccess, StoragePointerWriteAccess,
    StoragePathEntry, Vec, VecTrait, MutableVecTrait};
    use starknet::event::EventEmitter;
    use core::num::traits::Zero;
 #[storage]
    struct Storage {
        token_x: ContractAddress,
        token_y: ContractAddress,
        reserve_x: u256,
        reserve_y: u256,
        owner: ContractAddress,
    }

   #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LiquidityAdded: LiquidityAdded,
        SwapXToY: SwapXToY,
        SwapYToX: SwapYToX,
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityAdded {
        amount_x: u128,
        amount_y: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SwapXToY {
        amount_in: u128,
        amount_out: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SwapYToX {
        amount_in: u128,
        amount_out: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_x: ContractAddress, token_y: ContractAddress){
        let caller = get_caller_address();
        self.owner.write(caller);
        self.token_x.write(token_x);
        self.token_y.write(token_y);
        self.reserve_x.write(0);
        self.reserve_y.write(0);
    }

    fn get_amount_out(amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
        let amount_out = (amount_in * reserve_out) / (reserve_in + amount_in);
        assert(amount_out > 0, 'amount_out musnt be zero');
        return amount_out;
    }

    #[abi(embed_v0)]
    impl DexImpl of super::IDex<ContractState>{
        fn get_reserves(self: @ContractState) -> (u256, u256){
            return (self.reserve_x.read(), self.reserve_y.read());
        }

        fn add_liquidity(ref self: ContractState, x: u256, y: u256){
            assert(x > 0, 'amount must be bigger than zero');
            assert(y > 0, 'amount must be bigger than zero');
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'only caller can call this fn');
            let token_x = IERC20Dispatcher { contract_address: self.token_x.read() };
            token_x.transfer_from(caller, get_contract_address(), x);
            let token_y = IERC20Dispatcher { contract_address: self.token_y.read() };
            token_y.transfer_from(caller, get_contract_address(), y);
            self.reserve_x.write(self.reserve_x.read() + x);
            self.reserve_y.write(self.reserve_y.read() + y);
            self.emit(LiquidityAdded {
                amount_x: x.try_into().unwrap(),
                amount_y: y.try_into().unwrap()
                });
        }

        fn swap_x_to_y(ref self: ContractState, amount_in: u256){
            assert(amount_in > 0, 'amount_in musnt be zero');
            let (reserve_x, reserve_y) = self.get_reserves();
            assert(reserve_x > 0 && reserve_y > 0, 'both of reserves musnt be zero');
            let caller = get_caller_address();
            let amount_out = get_amount_out(amount_in, reserve_x, reserve_y);
            let token_x = IERC20Dispatcher { contract_address: self.token_x.read() };
            let token_y = IERC20Dispatcher { contract_address: self.token_y.read() };
            token_x.transfer_from(caller, get_contract_address(), amount_in);
            token_y.transfer(caller, amount_out);

            self.reserve_x.write(self.reserve_x.read() + amount_in);
            self.reserve_y.write(self.reserve_y.read() - amount_out);
            self.emit(SwapXToY { 
            amount_in: amount_in.try_into().unwrap(), 
            amount_out: amount_out.try_into().unwrap() 
        });

        }

        fn swap_y_to_x(ref self: ContractState, amount_in: u256){
            assert(amount_in > 0, 'amount_in musnt be zero');
            let (reserve_x, reserve_y) = self.get_reserves();
            assert(reserve_x > 0 && reserve_y > 0, 'both of reserves musnt be zero');
            let caller = get_caller_address();
            let token_x = IERC20Dispatcher { contract_address: self.token_x.read() };
            let token_y = IERC20Dispatcher { contract_address: self.token_y.read() };
            let amount_out = get_amount_out(amount_in, reserve_y, reserve_x);
            token_y.transfer_from(caller, get_contract_address(), amount_in);
            token_x.transfer(caller, amount_out);
            self.reserve_y.write(self.reserve_y.read() + amount_in);
            self.reserve_x.write(self.reserve_x.read() - amount_out);
            self.emit(SwapYToX { 
            amount_in: amount_in.try_into().unwrap(), 
            amount_out: amount_out.try_into().unwrap() 
        });

        }

        
    
    }
}


