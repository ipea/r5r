package org.ipea.r5r;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.util.*;

public class RDataFrame {
    private int rowCount = 0;
    private int currentRow = -1;

    public LinkedHashMap<String, ArrayList<Object>> getDataFrame() {
        return dataFrame;
    }

    public int nRow() {
        return rowCount;
    }
    public void updateRowCount() {
        if (columnNames.size() > 0) {
            rowCount = dataFrame.get(columnNames.get(0)).size();
        }
    }

    public void seek(int index) {
        if (index < rowCount) {
            this.currentRow = index;
        }
    }

    private final int capacity;

    private final LinkedHashMap<String, ArrayList<Object>> dataFrame;
    private final LinkedHashMap<String, Object> defaultValues;

    private final ArrayList<String> columnNames;
    private final ArrayList<String> columnTypes;

    public RDataFrame() {
        this(10);
    }

    public RDataFrame(int capacity) {
        this.capacity = capacity;
        
        dataFrame = new LinkedHashMap<>();
        defaultValues = new LinkedHashMap<>();

        columnNames = new ArrayList<>();
        columnTypes = new ArrayList<>();
    }

    public void append() {
        dataFrame.forEach((columnName, columnContents) -> {
            Object defaultValue = defaultValues.get(columnName);

            columnContents.add(defaultValue);
        });
        rowCount++;
    }

    public void appendRepeat() {
        dataFrame.forEach((columnName, columnContents) -> {
            Object lastValue = columnContents.get(columnContents.size() - 1);
            columnContents.add(lastValue);
        });
        rowCount++;
    }

    public void set(String columnName, String value) {
        List<Object> column = dataFrame.get(columnName);
        column.set(column.size() - 1, value);
    }

    public void set(String columnName, Boolean value) {
        List<Object> column = dataFrame.get(columnName);
        column.set(column.size() - 1, value);
    }

    public void set(String columnName, Integer value) {
        List<Object> column = dataFrame.get(columnName);
        column.set(column.size() - 1, value);
    }

    public void set(String columnName, Long value) {
        List<Object> column = dataFrame.get(columnName);
        column.set(column.size() - 1, value);
    }

    public void set(String columnName, Double value) {
        List<Object> column = dataFrame.get(columnName);
        column.set(column.size() - 1, value);
    }

    public void addStringColumn(String columnName, String defaultValue) {
        ArrayList<Object> column = new ArrayList<>(capacity);
        for (int i = 0; i < nRow(); i++) { column.add(defaultValue); }
        dataFrame.put(columnName, column);

        defaultValues.put(columnName, defaultValue);

        columnNames.add(columnName);
        columnTypes.add("String");
    }

    public void addBooleanColumn(String columnName, Boolean defaultValue) {
        ArrayList<Object> column = new ArrayList<>(capacity);
        for (int i = 0; i < nRow(); i++) { column.add(defaultValue); }
        dataFrame.put(columnName, column);

        defaultValues.put(columnName, defaultValue);

        columnNames.add(columnName);
        columnTypes.add("Boolean");
    }

    public void addIntegerColumn(String columnName, Integer defaultValue) {
        ArrayList<Object> column = new ArrayList<>(capacity);
        for (int i = 0; i < rowCount; i++) { column.add(defaultValue); }
        dataFrame.put(columnName, column);

        defaultValues.put(columnName, defaultValue);

        columnNames.add(columnName);
        columnTypes.add("Integer");
    }

    public void addLongColumn(String columnName, Long defaultValue) {
        ArrayList<Object> column = new ArrayList<>(capacity);
        for (int i = 0; i < rowCount; i++) { column.add(defaultValue); }
        dataFrame.put(columnName, column);

        defaultValues.put(columnName, defaultValue);

        columnNames.add(columnName);
        columnTypes.add("Long");
    }

    public void addDoubleColumn(String columnName, Double defaultValue) {
        ArrayList<Object> column = new ArrayList<>(capacity);
        for (int i = 0; i < nRow(); i++) { column.add(defaultValue); }
        dataFrame.put(columnName, column);

        defaultValues.put(columnName, defaultValue);

        columnNames.add(columnName);
        columnTypes.add("Double");
    }

    public int getColumnCount() { return columnNames.size(); }
    public String getColumnName(int index) { return columnNames.get(index); }
    public String getColumnType(int index) { return columnTypes.get(index); }
    public String getColumnType(String name) {
        int index = columnNames.indexOf(name);
        return columnTypes.get(index);
    }

    public String[] getColumnNames() { return columnNames.toArray(String[]::new); }
    public String[] getColumnTypes() { return columnTypes.toArray(String[]::new); }

    public ArrayList<Object> get(String columnName) { return dataFrame.get(columnName); }

    public String[] getStringColumn(String columnName) { return dataFrame.get(columnName).toArray(String[]::new); }

    // returns each value's 0-based position in ids, so R can rebuild the column as ids[pos + 1]
    // without converting one Java String per row (e.g. from_id / to_id of a travel time matrix)
    public int[] getStringColumnIndex(String columnName, String[] ids) {
        HashMap<String, Integer> positions = new HashMap<>(ids.length * 2);
        for (int i = 0; i < ids.length; i++) positions.putIfAbsent(ids[i], i);

        ArrayList<Object> column = dataFrame.get(columnName);
        int[] v = new int[column.size()];
        for (int i = 0; i < v.length; i++) {
            Integer pos = positions.get((String) column.get(i));
            if (pos == null) {
                throw new IllegalStateException("Value '" + column.get(i) + "' of column " + columnName + " is not among the ids supplied");
            }
            v[i] = pos;
        }
        return v;
    }
    public int[] getIntegerColumn(String columnName) {
        return dataFrame.get(columnName).stream().mapToInt(i -> (int) i).toArray();
    }
    public long[] getLongColumn(String columnName) {
        return dataFrame.get(columnName).stream().mapToLong(i -> (long) i).toArray();
    }
    public double[] getDoubleColumn(String columnName) {
        return dataFrame.get(columnName).stream().mapToDouble(d -> (double) d).toArray();
    }
    public boolean[] getBooleanColumn(String columnName) {
        ArrayList<Object> columnContents = dataFrame.get(columnName);
        int size = columnContents.size();
        boolean[] v = new boolean[size];
        for (int i = 0; i < size; i++) {
            v[i] = (boolean) columnContents.get(i);
        }
        return v;
    }

    public String getStringValue(String columnName) {
        ArrayList<Object> data = dataFrame.get(columnName);
        return data.get(currentRow).toString();
    }

    public long getLongValue(String columnName) {
        ArrayList<Object> data = dataFrame.get(columnName);
        return (Long) data.get(currentRow);
    }

    public int getIntValue(String columnName) {
        ArrayList<Object> data = dataFrame.get(columnName);
        return (Integer) data.get(currentRow);
    }

    public boolean getBooleanValue(String columnName) {
        ArrayList<Object> data = dataFrame.get(columnName);
        return (Boolean) data.get(currentRow);
    }

    public void clear() {
        columnNames.forEach(key -> {
            ArrayList<Object> column = dataFrame.get(key);
            column.clear();
        });
        rowCount = 0;
    }

    public void saveToCsv(String filename) throws FileNotFoundException {
        File csvOutputFile = new File(filename);

        try (PrintWriter pw = new PrintWriter(csvOutputFile)) {
            // save column titles
            StringJoiner row = new StringJoiner(",");
            columnNames.forEach(row::add);

            pw.println(row);

            // save data
            for (int i = 0; i < nRow(); i++) {
                row = new StringJoiner(",");

                for (String c:columnNames) {
                    row.add(csvField(Objects.toString(dataFrame.get(c).get(i), ""))); // null (NA) -> empty field
                }
                pw.println(row);
            }
        }
    }

    // quotes a value that contains a comma, a double quote or a line break
    // (e.g. WKT geometries, lists of ids), doubling any quotes inside it (RFC 4180)
    private static String csvField(String value) {
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }
}

