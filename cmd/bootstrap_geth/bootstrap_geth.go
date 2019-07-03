package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"path/filepath"
	"flag"
	"math/big"
	"time"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/keystore"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
)

var (
	chainIDFlag int
	numSignerAddressesFlag int
	numClientAddressesFlag int
	engineFlag string
	periodFlag int
	signerKeystoreFlag string
	clientKeystoreFlag string
	signerAuthFlag string
	clientAuthFlag string
	genesisFlag string
	signerFlag string
	clientFlag string
)

type accountKey struct {
	Address string `json:"address"`
}

type accountData struct {
	Addresses []string `json:"addresses"`
	Keys []json.RawMessage `json:"keys"`
}

func main() {
	flag.IntVar(&chainIDFlag, "chainID", 0, "network/chain ID")
	flag.IntVar(&numSignerAddressesFlag, "numSignerAddresses", 1, "number of signer addresses to create")
	flag.IntVar(&numClientAddressesFlag, "numClientAddresses", 1, "number of client addresses to create")
	flag.StringVar(&engineFlag, "engine", "clique", "consensus engine to use")
	flag.IntVar(&periodFlag, "period", 15, "clique period to use")
	flag.StringVar(&signerKeystoreFlag, "signerKeystore", "ethdata/signers", "directory to store signer account info")
	flag.StringVar(&clientKeystoreFlag, "clientKeystore", "ethdata/clients", "directory to store client account info")
	flag.StringVar(&signerAuthFlag, "signerAuth", "", "passphrase for new accounts")
	flag.StringVar(&clientAuthFlag, "clientAuth", "", "passphrase for new accounts")
	flag.StringVar(&genesisFlag, "genesisFilename", "genesis.json", "destination file for genesis json")
	flag.StringVar(&signerFlag, "signerFilename", "signers.json", "destination file for signer data json")
	flag.StringVar(&clientFlag, "clientFilename", "clients.json", "destination file for client data json")
	flag.Parse()

	if chainIDFlag == 0 {
		fmt.Printf("Invalid usage, run with -h\n")
		return
	}

	signers, err := findAccounts(signerKeystoreFlag)
	if err != nil {
		fmt.Println(err)
		return
	}
	clients, err := findAccounts(clientKeystoreFlag)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(signers) == 0 {
		signers, err = createAccounts(numSignerAddressesFlag, signerKeystoreFlag, signerAuthFlag)
		if err != nil {
			fmt.Println(err)
			return
		}
	}
	if len(clients) == 0 {
		clients, err = createAccounts(numClientAddressesFlag, clientKeystoreFlag, clientAuthFlag)
		if err != nil {
			fmt.Println(err)
			return
		}
	}

	signerData, err := makeAccountData(signers, signerKeystoreFlag)
	if err != nil {
		fmt.Println(err)
		return
	}
	clientData, err := makeAccountData(clients, clientKeystoreFlag)
	if err != nil {
		fmt.Println(err)
		return
	}

	if err := ioutil.WriteFile(signerFlag, signerData, 0644); err != nil {
		fmt.Println(err)
		return
	}

	if err := ioutil.WriteFile(clientFlag, clientData, 0644); err != nil {
		fmt.Println(err)
		return
	}

	genesis := makeGenesis(chainIDFlag, engineFlag, periodFlag, signers, clients)
	if err := ioutil.WriteFile(genesisFlag, genesis, 0644); err != nil {
		fmt.Println(err)
		return
	}
}

func findAccounts(keystorePath string) ([]common.Address, error) {
	var signers []common.Address
	files, err := filepath.Glob(keystorePath + "/*")
	if err != nil {
		return signers, fmt.Errorf("unable to find created accounts when searching for %s, error: %s", keystorePath, err)
	}
	for _, f := range files {
		keyjson, err := ioutil.ReadFile(f)
		if err != nil {
			return signers, fmt.Errorf("unable to find created accounts when searching for %s, error: %s", keystorePath, err)
		}
		var key accountKey
		if err := json.Unmarshal(keyjson, &key); err != nil {
			return signers, fmt.Errorf("unable to unmarshal created accounts when searching for %s, error: %s", keystorePath, err)
		}
		signers = append(signers, common.HexToAddress(key.Address))
	}
	return signers, nil
}

func makeAccountData(accounts []common.Address, keystorePath string) ([]byte, error){
	tmpl := keystorePath + "/*%s"
	accountData := &accountData{
		Addresses: []string{},
		Keys: []json.RawMessage{},
	}
	for _, a := range accounts {
		accountStr := strings.ToLower(strings.TrimPrefix(a.String(), "0x"))
		pattern := fmt.Sprintf(tmpl, accountStr)
		files, err := filepath.Glob(pattern)
		if err != nil {
			return nil, fmt.Errorf("unable to find created accounts when searching for %s, error: %s", pattern, err)
		}
		if len(files) != 1 {
			return nil, fmt.Errorf("unable to find created accounts when searching for %s, found %+v", pattern, files)
		}
		filename := files[0]
		var keyraw json.RawMessage
		keyjson, err := ioutil.ReadFile(filename)
		if err != nil {
			return nil, fmt.Errorf("unable to find created accounts when searching for %s, error %s", pattern, err)
		}
		if err := json.Unmarshal(keyjson, &keyraw); err != nil {
			return nil, fmt.Errorf("unable to unmarshal created accounts when searching for %s, error %s", pattern, err)
		}
		accountData.Keys = append(accountData.Keys, keyraw)
		accountData.Addresses = append(accountData.Addresses, accountStr)
	}
	accountDataStr, _ := json.MarshalIndent(accountData, "", "  ")
	return accountDataStr, nil
}

func makeGenesis(chainID int, engine string, period int, signers []common.Address, clients []common.Address) []byte {
	// Construct a default genesis block
	genesis := &core.Genesis{
		Timestamp:  uint64(time.Now().Unix()),
		GasLimit:   4700000,
		Difficulty: big.NewInt(524288),
		Alloc:      make(core.GenesisAlloc),
		Config: &params.ChainConfig{
			HomesteadBlock: big.NewInt(1),
			EIP150Block:    big.NewInt(2),
			EIP155Block:    big.NewInt(3),
			EIP158Block:    big.NewInt(3),
			ByzantiumBlock: big.NewInt(4),
			ChainID: new(big.Int).SetUint64(uint64(chainID)),
		},
	}

	if engine == "ethash" {
		genesis.Config.Ethash = new(params.EthashConfig)
		genesis.ExtraData = make([]byte, 32)

	} else {
		genesis.Config.Clique = &params.CliqueConfig{
			Period: uint64(period),
			Epoch:  30000,
		}
		genesis.Difficulty = big.NewInt(1)
		// Embed signers into the extra-data and alloc sections
		genesis.ExtraData = make([]byte, 32+len(signers)*common.AddressLength+65)
		for i, signer := range signers {
			copy(genesis.ExtraData[32+i*common.AddressLength:], signer[:])
		}
	}

	for _, signer := range signers {
		genesis.Alloc[signer] = core.GenesisAccount{
			Balance: new(big.Int).Lsh(big.NewInt(1), 256-7), // 2^256 / 128 (allow many pre-funds without balance overflows)
		}
	}

	for _, client := range clients {
		genesis.Alloc[client] = core.GenesisAccount{
			Balance: new(big.Int).Lsh(big.NewInt(1), 256-7),
		}
	}

	genesisStr, _ := json.MarshalIndent(genesis, "", "  ")
	return genesisStr
}

func createAccounts(numAccounts int, keystorePath, auth string) ([]common.Address, error) {
	var signers []common.Address
	for i := 0; i < numAccounts; i++ {
		if address, err := createAccount(keystorePath, auth); err == nil {
			signers = append(signers, address)
		} else {
			return signers, fmt.Errorf("unable to create account, error: %s", err)
		}
	}

	// Sort the signers
	for i := 0; i < len(signers); i++ {
		for j := i + 1; j < len(signers); j++ {
			if bytes.Compare(signers[i][:], signers[j][:]) > 0 {
				signers[i], signers[j] = signers[j], signers[i]
			}
		}
	}
	return signers, nil
}

func createAccount(keystorePath string, auth string) (common.Address, error) {
	address, err := keystore.StoreKey(
		keystorePath,
		auth,
		keystore.StandardScryptN,
		keystore.StandardScryptP)

	if err != nil {
		return address, fmt.Errorf("failed to create account: %v", err)
	}

	return address, nil
}
