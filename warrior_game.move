module shelby_warrior::warrior_game {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::timestamp;

    // ================== CONSTANTS ==================
    const MINT_FEE_APT: u64 = 100_000_000; // 1 APT (1 APT = 10^8 octas)
    const ENOT_ENOUGH_APT: u64 = 1;
    const EALREADY_HAS_WARRIOR: u64 = 2;
    const ENO_WARRIOR: u64 = 3;

    // ================== STRUCTS ==================
    /// Main Warrior NFT (one per player for simplicity; easily extendable to multiple)
    struct Warrior has key {
        name: String,
        strength: u64,
        agility: u64,
        health: u64,
        uri: String, // e.g. shelby.xyz/object/xxx for verifiable AI-generated art
    }

    /// Treasury to collect mint fees
    struct Treasury has key {
        apt: Coin<AptosCoin>,
    }

    /// Battle event for frontend listening
    struct BattleEvent has drop, store {
        attacker: address,
        defender: address,
        winner: address,
        timestamp: u64,
    }

    /// Global event store (publisher account)
    struct GameEvents has key {
        battle_events: EventHandle<BattleEvent>,
    }

    // ================== INITIALIZATION ==================
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        if (!account::exists_at(admin_addr)) {
            account::create_account_for_test(admin_addr);
        };

        // Create treasury
        if (!exists<Treasury>(admin_addr)) {
            move_to(admin, Treasury { apt: coin::zero<AptosCoin>() });
        };

        // Create global events
        if (!exists<GameEvents>(admin_addr)) {
            move_to(admin, GameEvents {
                battle_events: account::new_event_handle<BattleEvent>(admin),
            });
        };
    }

    // ================== PUBLIC ENTRY FUNCTIONS ==================
    /// Mint a warrior — costs 1 APT (goes to treasury)
    public entry fun mint_warrior(
        player: &signer,
        name: vector<u8>,
        strength: u64,
        agility: u64,
        health: u64,
        uri: vector<u8>   // Shelby URI recommended, e.g. "https://api.shelby.xyz/object/..."
    ) acquires Treasury {
        let player_addr = signer::address_of(player);

        // Pay mint fee
        assert!(coin::balance<AptosCoin>(player_addr) >= MINT_FEE_APT, error::invalid_argument(ENOT_ENOUGH_APT));
        let fee = coin::withdraw<AptosCoin>(player, MINT_FEE_APT);

        // Deposit to treasury
        let treasury = borrow_global_mut<Treasury>(@shelby_warrior);
        coin::merge(&mut treasury.apt, fee);

        // Prevent duplicate warrior per account
        assert!(!exists<Warrior>(player_addr), error::already_exists(EALREADY_HAS_WARRIOR));

        // Create warrior
        let warrior = Warrior {
            name: string::utf8(name),
            strength,
            agility,
            health,
            uri: string::utf8(uri),
        };

        move_to(player, warrior);
    }

    /// Battle another player's warrior
    public entry fun battle(
        attacker: &signer,
        defender_addr: address
    ) acquires Warrior, GameEvents {
        let attacker_addr = signer::address_of(attacker);

        assert!(exists<Warrior>(attacker_addr), error::not_found(ENO_WARRIOR));
        assert!(exists<Warrior>(defender_addr), error::not_found(ENO_WARRIOR));

        let attacker_warrior = borrow_global_mut<Warrior>(attacker_addr);
        let defender_warrior = borrow_global_mut<Warrior>(defender_addr);

        // Simple battle logic (deterministic + slight randomness via timestamp)
        let attack_power = attacker_warrior.strength + attacker_warrior.agility + (timestamp::now_microseconds() % 10);
        let defend_power = defender_warrior.strength + defender_warrior.agility;

        let winner_addr = if (attack_power > defend_power) {
            // Attacker wins — reduce defender health
            if (defender_warrior.health > 20) defender_warrior.health = defender_warrior.health - 20;
            attacker_addr
        } else {
            // Defender wins — reduce attacker health
            if (attacker_warrior.health > 20) attacker_warrior.health = attacker_warrior.health - 20;
            defender_addr
        };

        // Emit event
        let events = borrow_global_mut<GameEvents>(@shelby_warrior);
        event::emit_event(
            &mut events.battle_events,
            BattleEvent {
                attacker: attacker_addr,
                defender: defender_addr,
                winner: winner_addr,
                timestamp: timestamp::now_microseconds(),
            }
        );
    }

    // ================== VIEW FUNCTIONS (for frontend) ==================
    #[view]
    public fun get_warrior(player: address): (String, u64, u64, u64, String) acquires Warrior {
        assert!(exists<Warrior>(player), error::not_found(ENO_WARRIOR));
        let w = borrow_global<Warrior>(player);
        (w.name, w.strength, w.agility, w.health, w.uri)
    }

    #[view]
    public fun get_treasury_balance(): u64 acquires Treasury {
        let treasury = borrow_global<Treasury>(@shelby_warrior);
        coin::value(&treasury.apt)
    }
}
