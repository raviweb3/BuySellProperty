// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


// Property List
// Offers
// Sale Processing
// Transfer

contract PropertyMarket {
    enum PropertyType {
        Land,
        Farm,
        Apartment
    }

    enum OfferStatus {
        Pending,
        Accepted,
        Confirmed,
        Rejected,
        Canceled
    }

    struct Offer {
       uint256 propertyId;
       address buyer;
       uint256 price;
       uint256 processingFee;
       uint256 offeredOn; 
       OfferStatus status; 
       uint256 saleRecordId;
    }

    Offer[] private s_offers;

    mapping(uint256 => Offer) private s_indexToOffers;
    uint256 private s_offerIndex;

    struct Property{
       string name;
       string description;
       PropertyType propType; 
       uint256 price;
       bool isAvailable;
       bool inSaleProcess;
       uint256 listedOn; 
       address owner;
    }

    Property[] private s_properties;

    mapping(uint256 => Property) private s_indexToProperties;
    uint256 private s_propertyIndex;

    struct SaleRecord {
        uint256 propertyId;
        uint256 offerId;
        uint256 price;
        uint256 transferredOn; 
        address previousOwner;
        address newOwner;
        address authorizer;
    }

    SaleRecord[] private s_saleRecord;

    mapping(uint256 => SaleRecord) private s_indexTosaleRegister;
    uint256 private s_saleRecordIndex;

    address private s_authorizer;
    address private s_owner;

    uint256 private i_processingFee;

    constructor(address authorizer, uint256 processingFee){
       s_owner = msg.sender; 
       s_authorizer = authorizer;
       i_processingFee = processingFee;
       s_propertyIndex = 0;
       s_saleRecordIndex = 0;
    }

    receive() external payable{
        revert();
    }

    fallback() external payable{
        revert();
    }

    function listProperty(string memory name, string memory description, PropertyType propType, uint256 price) public {
        Property memory newProperty = Property(name, description, propType,price,true,false, block.timestamp, msg.sender);
        s_properties.push(newProperty);
        s_indexToProperties[s_propertyIndex]=newProperty;
        s_propertyIndex = s_propertyIndex + 1;

    }

    function createOffer(uint256 propertyId, uint256 price) public {
        require(s_indexToProperties[propertyId].owner != msg.sender,"You already own this property");

        Offer memory newOffer = Offer(propertyId,msg.sender,price, i_processingFee,block.timestamp,OfferStatus.Pending,0);
        s_offers.push(newOffer);
        s_indexToOffers[s_offerIndex]=newOffer;
        s_offerIndex = s_offerIndex + 1;
    }

    function acceptOffer(uint256 offerId) public {
       Offer storage offer = s_indexToOffers[offerId];
       
       require(s_indexToProperties[offer.propertyId].owner == msg.sender,"You have to be the owner");
       offer.status = OfferStatus.Accepted; 
    }

    // Initiating this function will lock both parties into an agreement.
    function initiateBuyProperty(uint256 offerId) public payable {
      Offer memory offer = s_indexToOffers[offerId];
      require(offer.buyer == msg.sender,"You did not make this offer");
      require(offer.status == OfferStatus.Accepted,"Offer is not accepted");

      uint256 totalPrice =  offer.price + offer.processingFee;
      require(totalPrice == msg.value, "Did not receive enough eth to start processing"); 
      
      // marks the ownership of the property to Authorizer
      s_indexToProperties[offer.propertyId].owner = s_authorizer;
      s_indexToProperties[offer.propertyId].isAvailable = false;
      s_indexToProperties[offer.propertyId].inSaleProcess = true;

      // Funds transferred to Authorizer
      (bool sent,) = payable(s_authorizer).call{value: msg.value}("");
      require(sent == true,"transaction failed");
    }

    function authoriseSale(uint256 offerId) public payable {
        require(s_authorizer == msg.sender,"You are not Authorised");
        Offer storage offer = s_indexToOffers[offerId];
        Property storage property = s_indexToProperties[offer.propertyId];

        // Sales Record
        SaleRecord memory newSaleRecord = SaleRecord(offer.propertyId,offerId,offer.price,block.timestamp,property.owner,offer.buyer,s_authorizer);
        s_saleRecord.push(newSaleRecord);
        s_indexTosaleRegister[s_saleRecordIndex] = newSaleRecord;

        // Transfer of Ownership to Buyer     
        offer.status =  OfferStatus.Confirmed;
        property.owner = offer.buyer;
        property.inSaleProcess = false;

        // Transfer Funds to Seller
        (bool sent2,) = payable(newSaleRecord.previousOwner).call{value: offer.price}("");
        require(sent2 == true,"transaction failed");
    }

    function readSaleRecord(uint256 saleRecordIndex) public view returns(SaleRecord memory){
        return s_indexTosaleRegister[saleRecordIndex];
    }

    function readProperty(uint256 propertyId)  public view returns(Property memory){
        return s_indexToProperties[propertyId];
    }

    function readProperties() public view returns(Property[] memory){
        return s_properties;
    }

     function readSaleRegister() public view returns(SaleRecord[] memory){
        return s_saleRecord;
    }
}
