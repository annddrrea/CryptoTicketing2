import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Function to auto-detect the latest deployed contract address
function getLatestContractAddress(): string | null {
  try {
    const broadcastPath = path.join(__dirname, '../../broadcast/Deploy.s.sol/31337/run-latest.json');
    
    if (fs.existsSync(broadcastPath)) {
      const broadcastData = JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));
      
      // Find the Ticket contract deployment transaction
      const ticketDeployment = broadcastData.transactions?.find(
        (tx: any) => tx.contractName === 'Ticket' && tx.transactionType === 'CREATE'
      );
      
      if (ticketDeployment) {
        console.log(`✅ Auto-detected Ticket contract address: ${ticketDeployment.contractAddress}`);
        return ticketDeployment.contractAddress;
      }
    }
    
    console.log('⚠️  Could not auto-detect contract address from broadcast file');
    return null;
  } catch (error) {
    console.error('❌ Error reading contract address:', error);
    return null;
  }
}

// Simple health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'CryptoTicketing backend is running' });
});

// Contract configuration endpoint
app.get('/api/config', (req, res) => {
  const contractAddress = getLatestContractAddress();
  
  res.json({
    contractAddress,
    rpcUrl: process.env.RPC_URL || 'http://localhost:8545',
    chainId: process.env.CHAIN_ID || 31337,
    network: process.env.NETWORK || 'anvil-local'
  });
});

// Basic hash endpoint for commitments
app.post('/api/hash', (req, res) => {
  const { data } = req.body;
  // Simple hash implementation - replace with proper crypto later
  const hash = Buffer.from(data).toString('hex');
  res.json({ hash });
});

// Events endpoint - returns event data for the frontend
app.get('/api/events', (req, res) => {
  const events = [
    {
      eventId: 1,
      name: 'Doja Cat: Tour Ma Vie World Tour',
      date: 'Dec 1, 2026',
      venue: 'Madison Square Garden, NY',
      description: 'Doja Cat will embark on the Tour Ma Vie World Tour in support of her fifth studio album Vie.',
    },
    {
      eventId: 2,
      name: 'Hamilton (NY)',
      date: 'Nov 4, 2025',
      venue: 'Richard Rodgers Theatre, NY',
      description: 'Hamilton is a sung-and-rapped-through musical that tells the story of American founding father Alexander Hamilton.',
      },
    {
      eventId: 3,
      name: '2025 Skechers World Champions Cup (Golf), Thursday',
      date: 'Dec 4, 2025',
      venue: 'Feather Sound Country Club',
      description: 'The Skechers World Champions Cup supporting Shriners Children’s is an annual three-team, three-day stroke play tournament that is now the fourth global team competition on the worldwide golf calendar.',
    },
  ];
  
  res.json({ events });
});

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});

export default app;