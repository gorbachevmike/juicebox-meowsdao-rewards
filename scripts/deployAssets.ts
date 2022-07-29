import * as dotenv from "dotenv";
import { BigNumber } from 'ethers';
import fs from 'fs';
import { NFTStorage, File } from 'nft.storage';
import path from 'path';

dotenv.config();

/**
 * Lists png files in a given location recursively.
 * @param location 
 */
async function listAssets(location: string) {
    const contents = fs.readdirSync(location);
    const traits: any = {};
    for (const c of contents) {
        if (fs.lstatSync(path.join(location, c)).isDirectory()) {
            traits[c] = [];
            const ccontents = fs.readdirSync(path.join(location, c));
            for (const cc of ccontents) {
                if (fs.lstatSync(path.join(location, c, cc)).isFile() && path.parse(cc).ext === '.png') {
                    traits[c].push(`${path.parse(cc).name}${path.parse(cc).ext}`);
                }
            }
        }
    }

    console.log(JSON.stringify(traits))
}

/**
 * Expects to find an assetIndex.json file at the source containing assets to be processed with full names and in the correct order.
 * 
 * @param source 
 * @param destination 
 */
async function renameAssets(source: string, destination: string) {
    const layers = JSON.parse(fs.readFileSync(path.join(source, 'assetIndex.json')).toString());

    const layerNames = Object.keys(layers);

    if (!fs.existsSync(destination)){
        fs.mkdirSync(destination);
    }

    const details: any = {};
    let offset = 0;
    for (let i = 0; i < layerNames.length; i++) {
        const group = layerNames[i];
        const layerOptions = layers[group];

        for (let j = 0; j < layerOptions.length; j++) {
            const item = layerOptions[j];
            const filenameIndex = j + 1; // NOTE: without this all 0-index file will collide
            const fileName = BigNumber.from(filenameIndex).shl(offset).toString();

            const imageSource = path.resolve(source, group, `${item}`);
            const imageDestination = path.resolve(destination, `${fileName}`);
            fs.copyFileSync(imageSource, imageDestination, fs.constants.COPYFILE_EXCL);
            console.log(`${group}/${item}->${fileName} (${filenameIndex}, ${offset})`);
        }

        const width = Math.ceil(Math.log2(layerOptions.length));

        details[group] = { cardinality: layerOptions.length, offset};

        let mask = 1;
        if (width == 0) {
            offset += 1;
        } else if (width <= 4) {
            offset += 4;
            mask = 2**4 - 1;
        } else if (width <= 6) {
            offset += 6;
            mask = 2**6 - 1;
        } else if (width <= 8) {
            offset += 8;
            mask = 2**8 - 1;
        } else if (width <= 12) {
            offset += 12;
            mask = 2**12 - 1;
        } else if (width <= 16) {
            offset += 16;
            mask = 2**16 - 1;
        }

        details[group].mask = mask;
    }

    console.log(JSON.stringify(details, undefined, 2));
}

async function uploadAssets(source: string, deleteAfterUpload = true) {
    const fileNames: string[] = fs.readdirSync(source);
    const fileContent: File[] = [];

    for (const name of fileNames) {
        fileContent.push(new File([fs.readFileSync(path.resolve(source, name))], name));
    }

    const storage = new NFTStorage({ endpoint: new URL('https://api.nft.storage'), token: process.env.NFT_STORAGE_API_KEY || '' });

    try {
        const cid = await storage.storeDirectory(fileContent);

        console.log({ cid });
        const status = await storage.status(cid);
        console.log(status);
    } catch (error) {
        console.log(error)
    }

    if (deleteAfterUpload) {
        fs.rmdirSync(source);
    }
}

async function main() {
    // listAssets('assets');
    // renameAssets('assets', 'scratch');
    // uploadAssets('scratch', false);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


