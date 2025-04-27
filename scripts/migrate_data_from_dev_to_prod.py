from populate_artists import ArtistManager

def main():
    dev_client = ArtistManager("dev").client
    prod_client = ArtistManager("prod").client

    dev_artists = list(dev_client["discovery"]["artists_v2"].find({}))
    dev_workshop_data = list(dev_client["discovery"]["workshops_v2"].find({}))
    dev_studio_data = list(dev_client["discovery"]["studios"].find({}))


    prod_client["discovery"]["artists_v2"].insert_many(dev_artists)
    prod_client["discovery"]["workshops_v2"].insert_many(dev_workshop_data)
    prod_client["discovery"]["studios"].insert_many(dev_studio_data)

    print(f"Migrated {len(dev_artists)} artists")
    print(f"Migrated {len(dev_workshop_data)} workshops")
    print(f"Migrated {len(dev_studio_data)} studios")
    print("Data migrated successfully")

if __name__ == "__main__":
    main()
    
