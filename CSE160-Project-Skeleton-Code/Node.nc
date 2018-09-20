/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

typedef nx_struct neighbor {
	nx_uint16_t Node;
	nx_uint16_t Age;
} neighbor;


module Node{
   uses interface Boot;
   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface Random as Random;
   uses interface List<pack> as nodesVisited;
   uses interface List<neighbor *> as ListOfNeighbors;
   uses interface Pool<neighbor> as NeighborPool;
   uses interface Timer<TMilli> as NeighborTimer;

}


implementation{

   pack sendPackage;
   pack replyPackage;

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   bool isPacketValid(pack *Package);



   void CheckandAge_Neighbors();

   uint16_t seqCounter = 1;
   uint16_t seq = 0;
   uint16_t replySeq = 0;
   uint32_t start, offset;
   neighbor *currentNeighbor;
   event void Boot.booted(){


   call AMControl.start();

	 start = call Random.rand32() % 2000;
	 offset = 20000 + (call Random.rand32() % 5000);

	 call NeighborTimer.startPeriodicAt(start, offset);
	 dbg(GENERAL_CHANNEL, "Boot began with   starting at %d, firing every %d\n\n\n", start, offset);


   dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event void NeighborTimer.fired() {}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){									//this function is going to have a lot of different checks
      dbg(GENERAL_CHANNEL, "Packet Received\n");

      if(len==sizeof(pack)){																//checks to see if the packet has changed

        pack* myMsg=(pack*) payload;
	      bool isValid;
	      isValid = isPacketValid(myMsg);

	      if (isValid == FALSE) {																//checks to see if the packet still needs to be flooded
		      //dbg(GENERAL_CHANNEL, "Found a recirculating package, no longer flooding the packet \n\n");

	      } else if (isValid == TRUE && myMsg->protocol == 0) {												//checks to see if the packet still needs to be flooded

		    dbg(GENERAL_CHANNEL, "Package Received from Node: %d at Node: %d\n\n", myMsg->src, TOS_NODE_ID);						//writes to the output line where the packet currently is
		    dbg(FLOODING_CHANNEL, "Flooding Channel Message - Package received at Node %d, is meant for Node %d \n\n", TOS_NODE_ID, myMsg->dest);	//writes to the output line where the packet needs to be

	      }

	//Write something to add the Packet to the Packet History List
       call nodesVisited.pushback(*myMsg);

	     if (TOS_NODE_ID == myMsg->dest) {														//checks to see if the package is at the destination

		     dbg(GENERAL_CHANNEL, "Package is at correct destination! Package from Node: %d, at destination Node: %d, Package Payload: %s\n\n", myMsg->payload);

	     } else if (TOS_NODE_ID != myMsg->dest) {
		     uint16_t myProtocol = myMsg->protocol;
         uint16_t i = 0;
         uint16_t neighborSize;
         bool neighborDiscovered = TRUE;

         switch(myProtocol){

		       case 0:		//myProtocol == 0, ping						//if package is not at the right destination, then repackage
			        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL - 1, myMsg->protocol = 0, myMsg->seq, myMsg->payload, sizeof(myMsg->payload));		//not sure if this is right, makes the new package
			        call Sender.send(sendPackage, AM_BROADCAST_ADDR);	//not sure if right					//sends the new package to the next node

              //send discovery packet by flipping source and destination. add static number to sequence.

              makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 1, seq + 100, myMsg->payload, sizeof(myMsg->payload));
              call Sender.send(sendPackage, AM_BROADCAST_ADDR);
              dbg(NEIGHBOR_CHANNEL,"Neighbor Channel Message - Discovered Node, sending discovery packet.\n\n",myMsg->src);
			        break;

	//Need to send discovery packet to neighbors, perhaps for neighbor discovery?

		      case 1:		//myProtocol = 1, pingreply

             neighborSize = call ListOfNeighbors.get(); //size of amount of neighbors


             //check to see if list has been initialized
             if (neighborSize == 0) { //if it has not, initialize
                currentNeighbor = call NeighborPool.get();

                currentNeighbor -> Node = myMsg -> src; //source of packet is neighbor address
                currentNeighbor -> Age = 0; //

                neighborDiscovered == TRUE;

                call ListOfNeighbors.pushback(currentNeighbor);

                //put dbg message here
             }

             else {

                while (neighborDiscovered == TRUE) {

                  currentNeighbor = call ListOfNeighbors.get(i);

                  if (myMsg -> dest == currentNeighbor -> Node) {
                    neighborDiscovered == FALSE;
                    currentNeighbor -> Age = 0;

                    //dbg msg
                  }
                  i++;
                }

                if (neighborDiscovered == TRUE) {
                  call nodesVisited.pushback(currentNeighbor);
                }
             }
			       break;


		      case 2: 	//myProtocol == 2, used later
			       break;

		      case 3:
			       break;

		      case 4:
			       break;

		      case 5:
			       break;

      		default: 	//don't know protocol
			       dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
             call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	        	 return msg;
		     }
      }
  }
   return msg;
}

    bool isPacketValid(pack* myMsg) {															//function to check if the packet is a recirculating packet

	  uint16_t i = 0;
	  uint16_t list = call nodesVisited.size();

	  if (list == 0)														//Check to see if this packet has gone to any other nodes
		return TRUE;

	  else if (myMsg->TTL == 0) {												//Check to see if packet should still be living

		dbg(FLOODING_CHANNEL, "TTL of this packet has reached zero");
		return FALSE;
    }

	  else {														//we need to iterate through the list to see if the packet is a recirculating packet

		for (i = 0; i < list; i++) {

			pack currentPack;
			currentPack = call nodesVisited.get(i);

			if (currentPack.src == myMsg->src && currentPack.dest == myMsg->dest && currentPack.seq == myMsg->seq) {			//checks to see if this is a recirculating package

				//dbg(FLOODING_CHANNEL, "This packet has already flooded through all the nodes");
				return FALSE;
			}
		}
	return TRUE;
	}
}

void Neighbors() {
  uint16_t listSize;
  uint16_t age;
}

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 15, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
