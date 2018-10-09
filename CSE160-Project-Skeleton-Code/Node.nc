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




   uint16_t seqCounter = 1;
   uint16_t seq = 0;
   uint16_t replySeq = 0;
   uint32_t start, offset;
   neighbor *currentNeighbor;
   neighbor *Neighbor;
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

   void neighborCheck() {
   uint16_t i = 0;
   uint16_t list = call nodesVisited.size();

  makePack(&sendPackage, TOS_NODE_ID, TOS_NODE_ID, 1, 0, seq++, "HI NEIGHBOR", PACKET_MAX_PAYLOAD_SIZE);
  call Sender.send(sendPackage, AM_BROADCAST_ADDR);

     for(i = 0; i < list;i++){
         dbg(NEIGHBOR_CHANNEL,"i am printing\n");
         //uint16_t Neighbor = call nodesVisited.get(i);
         //printf('%s', Neighbor);
         //dbg(NEIGHBOR_CHANNEL,"Neighboring nodes %s\n", Neighbor);

         }
   }

   event void NeighborTimer.fired() {
   dbg(GENERAL_CHANNEL, "HELLO");
    neighborCheck();
   }

   bool isPacketValid(uint16_t from, pack* myMsg) {															//function to check if the packet is a recirculating packet

   uint16_t i = 0;
   uint16_t list = call nodesVisited.size();

   if (list == 0)														//Check to see if this packet has gone to any other nodes
   return TRUE;

   else {														//we need to iterate through the list to see if the packet is a recirculating packet

   for (i = 0; i < list; i++) {

     pack currentPack;
     currentPack = call nodesVisited.get(i);

     if (currentPack.src == myMsg->src && currentPack.seq == myMsg->seq) {			//checks to see if this is a recirculating package
       return TRUE;
     }
   }
 return FALSE;
 }
}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){									//this function is going to have a lot of different checks


           if(len==sizeof(pack)){
               pack* myMsg=(pack*) payload;
               // dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
               if (myMsg -> TTL == 0){
                   //dbg(FLOODING_CHANNEL, "Packet Dropped due to TTL at 0\n");
                   return msg;
               }
               else if (myMsg -> dest != TOS_NODE_ID){
                   if (isPacketValid(myMsg -> src, *myMsg) == TRUE)
                       return msg;
                   else if (myMsg -> src == myMsg -> dest){
                       int has = 0, i = 0;
                       for (i = 0; i < call ListOfNeighbors.size(); i++){
                           int temp = call ListOfNeighbors.get(i);
                           if (temp == myMsg -> src)
                               has++;
                       }
                       if (has == 0)
                           call ListOfNeighbors.pushback(myMsg -> src);

                   }
                   call nodesVisited.pushback(*myMsg);

                   myMsg -> TTL -= 1;
                   dbg(FLOODING_CHANNEL, "Packet Received from %d, flooding\n", myMsg->src);

                   call Sender.send(*myMsg, AM_BROADCAST_ADDR);
               }


               else if (myMsg -> protocol == 1 && myMsg -> dest == TOS_NODE_ID){
                   dbg(GENERAL_CHANNEL, "Packet Recieved: %s\n", myMsg -> payload);
               }
               else { // myMsg -> dest == TOS_NODE_ID
                   dbg(GENERAL_CHANNEL, "Packet Recieved: %s\n", myMsg -> payload);
                   call Packets.pushback(*myMsg);
                   makePack(&sendPackage, TOS_NODE_ID, myMsg -> src, MAX_TTL, 1, seq++, "Thank You.", PACKET_MAX_PAYLOAD_SIZE);
                   call Sender.send(sendPackage, AM_BROADCAST_ADDR);
               }
               return msg;
           }
           dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
           return msg;
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
