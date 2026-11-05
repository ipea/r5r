package org.ipea.r5r.Network;

import com.conveyal.kryo.InstanceCountingClassResolver;
import com.conveyal.kryo.TIntArrayListSerializer;
import com.conveyal.kryo.TIntIntHashMapSerializer;
import com.conveyal.r5.kryo.KryoNetworkSerializer;
import com.esotericsoftware.kryo.Kryo;
import com.esotericsoftware.kryo.io.Input;
import com.esotericsoftware.kryo.serializers.ExternalizableSerializer;
import com.esotericsoftware.kryo.serializers.JavaSerializer;
import com.esotericsoftware.kryo.util.DefaultInstantiatorStrategy;
import gnu.trove.impl.hash.TPrimitiveHash;
import gnu.trove.list.array.TIntArrayList;
import gnu.trove.map.hash.TIntIntHashMap;
import org.objenesis.strategy.SerializingInstantiatorStrategy;
import org.slf4j.LoggerFactory;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.Arrays;
import java.util.BitSet;

public class NetworkChecker {

    /**
     * Network storage format version required by the R5 version in use. Taken from R5 itself, so that networks
     * written by a different R5 version are rebuilt instead of failing to load.
     */
    public static final String NETWORK_FORMAT_VERSION = KryoNetworkSerializer.NETWORK_FORMAT_VERSION;

    public static final byte[] HEADER = "R5NETWORK".getBytes();

    /** Set this to true to count instances and print a report including which serializer is handling each class. */
    private static final boolean COUNT_CLASS_INSTANCES = false;

    private static final org.slf4j.Logger LOG = LoggerFactory.getLogger(NetworkChecker.class);

    public static boolean checkR5NetworkVersion(String dataFolder) throws FileNotFoundException {
        LOG.info("Reading transport network...");

        File file = new File(dataFolder, "network.dat");
        Input input = new Input(new FileInputStream(file));
        Kryo kryo = makeKryo();
        byte[] header = new byte[HEADER.length];
        input.read(header, 0, header.length);
        if (!Arrays.equals(HEADER, header)) {
            throw new RuntimeException("Unrecognized file header. Is this an R5 Kryo network?");
        }
        String formatVersion = kryo.readObject(input, String.class);
        String commit = kryo.readObject(input, String.class);
        input.close();

        LOG.info("Loading network from file format version {}, written by R5 commit {}", formatVersion, commit);

        if (!NETWORK_FORMAT_VERSION.equals(formatVersion)) {
            LOG.warn("Network file format version is {}, this R5 requires {}; rebuilding network.",
                    formatVersion, NETWORK_FORMAT_VERSION);
            return false;
        } else { return true; }
    }

    /**
     * Factory method ensuring that we configure Kryo exactly the same way when saving and loading networks, without
     * duplicating code. We could explicitly register all classes in this method, which would avoid writing out the
     * class names the first time they are encountered and guarantee that the desired serialization approach was used.
     * Because these networks are so big though, pre-registration should provide very little savings.
     * Registration is more important for small network messages.
     */
    private static Kryo makeKryo () {
        Kryo kryo;
        if (COUNT_CLASS_INSTANCES) {
            kryo = new Kryo(new InstanceCountingClassResolver(), null);
        } else {
            kryo = new Kryo();
        }
        // Auto-associate classes with default serializers the first time each class is encountered.
        kryo.setRegistrationRequired(false);
        // Handle references and loops in the object graph, do not repeatedly serialize the same instance.
        kryo.setReferences(true);
        // Hash maps generally cannot be properly serialized just by serializing their fields.
        // Kryo's default serializers and instantiation strategies don't seem to deal well with Trove primitive maps.
        // Certain Trove class hierarchies are Externalizable though, and define their own optimized serialization
        // methods. addDefaultSerializer will create a serializer instance for any subclass of the specified class.
        // The TPrimitiveHash hierarchy includes all the trove primitive-primitive and primitive-Object implementations.
        kryo.addDefaultSerializer(TPrimitiveHash.class, ExternalizableSerializer.class);
        // We've got a custom serializer for primitive int array lists, because there are a lot of them and the custom
        // implementation is much faster than deferring to their Externalizable implementation.
        kryo.register(TIntArrayList.class, new TIntArrayListSerializer());
        // Likewise for TIntIntHashMaps - there are lots of them in the distance tables.
        kryo.register(TIntIntHashMap.class, new TIntIntHashMapSerializer());
        // Kryo's default instantiation and deserialization of BitSets leaves them empty.
        // The Kryo BitSet serializer in magro/kryo-serializers naively writes out a dense stream of booleans.
        // BitSet's built-in Java serializer saves the internal bitfields, which is efficient. We use that one.
        kryo.register(BitSet.class, new JavaSerializer());
        // Instantiation strategy: how should Kryo make new instances of objects when they are deserialized?
        // The default strategy requires every class you serialize, even in your dependencies, to have a zero-arg
        // constructor (which can be private). The setInstantiatorStrategy method completely replaces that default
        // strategy. The nesting below specifies the Java approach as a fallback strategy to the default strategy.
        kryo.setInstantiatorStrategy(new DefaultInstantiatorStrategy(new SerializingInstantiatorStrategy()));
        return kryo;
    }

}
